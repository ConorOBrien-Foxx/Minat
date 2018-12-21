require_relative "tokenizer.rb"
require_relative "error.rb"

class MinatShuntEntity
    def initialize(token, payload=nil, payload_type=nil)
        @token = token
        @payload = payload
        @payload_type = payload_type
    end

    attr_reader :token, :payload

    [:raw, :pos].each { |prop|
        define_method(prop) {
            @token.send prop
        }
    }

    def type
        @payload_type || @token&.type
    end

    def self.arity(n, type=:call_func)
        MinatShuntEntity.new(nil, n, type)
    end

    def to_s
        trep = MinatToken === @token ? @token.to_s : @payload_type.inspect
        "MSE(#{trep}, #{payload.inspect})"
    end
end

def flush(out, stack, fin=[])
    out.push stack.pop until stack.empty? || fin.include?(stack.last.type)
end



class MinatShunter
    def initialize(code)
        @code = code
        @ptr = 0
        @output_queue = []
        @operator_stack = []
        @arity_stack = []
        @last_parsed = nil

        if String === @code
            @code = tokenize @code
        end
    end

    def running?
        @code[@ptr]
    end

    def output(ent, type=nil)
        case ent
            when MinatToken
                @output_queue << MinatShuntEntity.new(ent, *type)
            when MinatShuntEntity
                @output_queue << ent
            else
                @output_queue << MinatShuntEntity.arity(ent, *type)
        end
    end

    def stack_push(ent)
        @operator_stack << ent
    end

    def step
        token = @code[@ptr]

        flush_stack = token.type == :separator

        if flush_stack
            flush :lambda_start
        end

        if MinatTokenizer.data? token
            output token

        elsif MinatTokenizer.operator? token
            prec, assoc = MinatTokenizer.precedence token

            if token.type == :operator
                loop {
                    break if @operator_stack.empty?
                    top = @operator_stack.last
                    top_prec, top_assoc = MinatTokenizer.precedence top

                    break unless top_prec
                    break if top_prec < prec
                    break if top_assoc == :left && top_prec == prec

                    output @operator_stack.pop
                }
            end
            stack_push token

        elsif token.type == :bracket_open
            # From Attache, property accessing:
            # | if !@operator_stack.empty? && @operator_stack.last.raw == "."
            # |     output @operator_stack.pop
            # | end

            stack_push token
            @arity_stack << 1

        elsif token.type == :array_start
            stack_push token
            @arity_stack << 1

        elsif token.type == :comma
            @arity_stack[-1] += 1
            flush :lambda_start, :array_start, :bracket_open

        elsif token.type == :array_end
            arity = @arity_stack.pop

            if @last_parsed.type == :array_start
                arity = 0
            end
            loop {
                if @operator_stack.empty?
                    raise MinatSyntaxError.new("Expected matching `]`")
                end
                last = @operator_stack.pop
                break if last.type == :array_start
                output last
            }
            output arity, :gather_array

        elsif token.type == :bracket_close
            arity = @arity_stack.pop

            if @last_parsed.type == :bracket_open
                arity = 0
            end
            loop {
                if @operator_stack.empty?
                    raise MinatSyntaxError.new("Expected matching `]`")
                end
                last = @operator_stack.pop
                break if last.type == :bracket_open
                output last
            }
            output arity

        elsif token.type == :paren_open
            stack_push token

        elsif token.type == :paren_close
            loop {
                if @operator_stack.empty?
                    raise MinatSyntaxError.new("Expected matching `)`")
                end
                last = @operator_stack.pop
                break if last.type == :paren_open
                output last
            }

        elsif token.type == :lambda_start
            output token
            stack_push token

        elsif token.type == :lambda_end
            flush :lambda_start
            @operator_stack.pop
            output token

        elsif !MinatTokenizer.significant?(token)
            # do nothing

        else
            STDERR.puts "Unhandled token type #{token.type.inspect}"
        end

        if MinatTokenizer.significant? token
            @last_parsed = token
        end

        @ptr += 1
    end

    def flush(*to)
        until @operator_stack.empty? || to.include?(@operator_stack.last.type)
            output @operator_stack.pop
        end
    end

    def shunt
        step while running?

        flush

        @output_queue
    end
end

def shunt(code)
    MinatShunter.new(code).shunt
end
