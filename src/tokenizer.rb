class MinatToken
    def initialize(type, raw, pos)
        @type = type
        @raw = raw
        @pos = pos
    end

    def to_s
        "Token(#{type.inspect}, #{raw.inspect}, #{pos})"
    end

    attr_reader :type, :raw, :pos
end

class MinatTokenizer
    def initialize(code)
        @code = code
        @ptr = 0
        @builds = []
        @tokens = []
        @last_token = nil
        @bracket_types = []
    end

    attr_reader :tokens

    def self.type_of(token)
        if MinatToken === token
            token.type
        else
            token
        end
    end

    DATA_TOKEN_TYPES = [
        :number, :string, :word, :abstract
    ]
    def self.data?(type)
        DATA_TOKEN_TYPES.include? type_of type
    end
    DATA_SIGNIFIERS = [
        :bracket_close,
        :paren_close,
        :array_end,
        :lambda_end,
    ] + DATA_TOKEN_TYPES
    def self.data_signifier?(type)
        DATA_SIGNIFIERS.include? type_of type
    end

    OPERATOR_TOKEN_TYPES = [
        :operator, :unary_operator
    ]
    def self.operator?(type)
        OPERATOR_TOKEN_TYPES.include? type_of type
    end

    INSIGNIFICANT_TYPES = [
        :whitespace,
        :separator,
    ]
    def self.significant?(type)
        !INSIGNIFICANT_TYPES.include?(type_of type)
    end

    def cur
        @code[@ptr]
    end

    def advance
        @code[(@ptr += 1) - 1]
    end

    def rest
        @code[@ptr..-1]
    end

    PRECEDENCE = {
        ":="    => [5,  :left],
        ".="    => [5,  :left],
        "="     => [20, :left],
        "=>"    => [30, :left],
        "+"     => [50, :left],
        "-"     => [50, :left],
        "*"     => [60, :left],
        "/"     => [60, :left],
        "^"     => [80, :right],
        # "%"   => [60, :left],
    }
    UNARY_PRECEDENCE = Hash.new(Float::INFINITY)
    def self.precedence(token)
        prec, assoc = PRECEDENCE[token.raw]
        if token.type == :unary_operator
            prec = UNARY_PRECEDENCE[token.raw]
        end
        [prec, assoc]
    end

    TOKEN_ORDER = [
        :operator,
        :unary_operator,
        :whitespace,
        :number,
        :string,
        :word,
        :abstract,

        :separator,

        :bracket_open,
        :array_start,
        :bracket_close,
        :array_end,

        :paren_open,
        :paren_close,
        :comma,
        :lambda_start,
        :lambda_end,
        :other,
    ]
    def step
        initial = @ptr
        TOKEN_ORDER.find { |type|
            build = send :"read_#{type}"

            if build
                token = append_token type, build, initial

                if MinatTokenizer.significant? type
                    @last_token = token
                end
            end

            build
        }
    end

    def run
        step while @code[@ptr]
    end

    def append_token(type, build, initial)
        token = MinatToken.new(type, build, initial)
        @tokens << token
        token
    end

    def matches?(reg)
        (rest =~ reg)&.zero?
    end

    def has_prefix?(prefix)
        rest.index(prefix)&.zero?
    end

    def start_build
        @builds << ""
    end

    def finish_build
        @builds.pop
    end

    def append_build(c)
        @builds.last&.<< c
    end
    def append_next(n=1)
        n.times {
            append_build cur
            advance
        }
    end
    def append_match(reg)
        ind = rest =~ reg
        if ind.zero?
            append_next $&.size
        else
            nil
        end
    end

    def build
        start_build
        yield
        finish_build
    end

    def self.define_read(name, char)
        define_method(:"read_#{name}") {
            return unless cur == char

            build {
                append_next 1
            }
        }
    end

    def read_bracket_open
        return unless cur == '['

        # the only other option is `array_start`
        if MinatTokenizer.data_signifier? @last_token
            @bracket_types << :call
        else
            @bracket_types << :array
            return
        end
        build {
            append_next 1
        }
    end
    define_read :array_start,       '['

    def read_bracket_close
        return unless cur == ']'
        # the only other option is `array_end`
        # we can pop here and save expanding the array_end definition
        return unless @bracket_types.pop == :call

        build {
            append_next 1
        }
    end
    define_read :array_end,         ']'

    define_read :paren_open,        '('
    define_read :paren_close,       ')'
    define_read :lambda_start,      '{'
    define_read :lambda_end,        '}'
    define_read :comma,             ','
    define_read :separator,         ';'

    NUMBER_PREFIX = DIGIT = /\d/
    NUMBER_BODY = /[\d.]/
    def read_number
        return unless matches? NUMBER_PREFIX

        build {
            append_next 1 while matches? NUMBER_BODY
        }
    end

    ABSTRACT_PREFIX = /_/
    def read_abstract
        return unless matches? ABSTRACT_PREFIX

        build {
            append_next 1 while matches? ABSTRACT_PREFIX
            append_next 1 while matches? DIGIT
        }
    end

    STRING_DELIM = /"/
    STRING_ESCAPE = /\\/
    def read_string
        return unless matches? STRING_DELIM

        build {
            append_next 1
            loop {
                case cur
                when STRING_ESCAPE
                    append_next 2
                when STRING_DELIM
                    append_next 1
                    break
                else
                    append_next 1
                end
            }
        }
    end

    WORD_START = /[a-zA-Z]/
    def read_word
        return unless matches? WORD_START

        build {
            append_match /\w+/
        }
    end

    def last_was_not_data?
        @tokens.last.nil? || !MinatTokenizer.data_signifier?(@last_token)
    end

    def read_operator(last_op_check=true)
        return if last_op_check && last_was_not_data?

        key = PRECEDENCE.keys.find { |key|
            has_prefix? key
        }

        return if key.nil?

        build {
            append_next key.size
        }
    end

    def read_unary_operator
        read_operator false
    end

    def read_whitespace
        return unless matches? /\s/

        build {
            append_match /\s+/
        }
    end

    def read_other
        build {
            append_next 1
        }
    end
end

def tokenize(code)
    tokenizer = MinatTokenizer.new code
    tokenizer.run
    tokenizer.tokens
end
