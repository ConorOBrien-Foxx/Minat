require_relative "tokenizer.rb"
require_relative "shunter.rb"

class MinatNode
    def initialize(head, children)
        @head = head
        @children = children
    end

    attr_reader :head, :children

    def to_s(level=0)
        str = ""
        prefix = "  " * level
        str += prefix + @head.to_s + "\n"
        @children.each { |child|
            str += prefix
            str += " -- "
            str += case child
                when MinatNode
                    child.to_s(level + 1).strip
                else
                    child.to_s
            end
            str += "\n"
        }
        str
    end

end

class MinatASTParser
    def initialize(code)
        @shunted = shunt code
        @ptr = 0
        @data_stack = []
        @stack_stack = []
    end

    # read-only
    def data_stack
        @data_stack.dup
    end

    def step
        cur = @shunted[@ptr]
        if MinatTokenizer.data? cur.token
            @data_stack << cur

        elsif MinatTokenizer.operator? cur.token
            arity = 2
            arity = 1 if cur.type == :unary_operator
            children = @data_stack.pop arity
            @data_stack << MinatNode.new(cur, children)

        elsif cur.type == :lambda_start
            @stack_stack << @data_stack
            @data_stack = []

        elsif cur.type == :lambda_end
            ds = @data_stack
            @data_stack = @stack_stack.pop
            @data_stack << MinatNode.new(:lambda, ds)

        elsif cur.type == :call_func
            arity = cur.payload
            children = @data_stack.pop arity
            caller = @data_stack.pop
            @data_stack << MinatNode.new(caller, children)

        elsif cur.type == :gather_array
            count = cur.payload
            children = @data_stack.pop count
            @data_stack << MinatNode.new(:array, children)

        else
            STDERR.puts "[AST] Idk: #{cur}"
        end
        @ptr += 1
    end

    def parse
        step while @shunted[@ptr]
        data_stack
    end
end

def ast(code)
    parser = MinatASTParser.new(code)
    parser.parse
end
