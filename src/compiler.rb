require_relative "ast.rb"
require_relative "tokenizer.rb"

# abstract class; needs to be extended
class MinatCompiler
    def initialize(code)
        @trees = ast code
        @prefix = []
        @suffix = []
    end

    def prepend(str)
        @prefix << str
    end

    def append(str)
        @suffix << str
    end

    def raise_unimplemented
        raise "unimplemented"
    end

    def compile_node(node)
        head = node.head
        children = node.children
        case (head.type rescue head)
            when :operator
                parse_operator head, children
            when :unary_operator
                parse_unary_operator head, children
            when :lambda
                parse_lambda children
            when MinatNode, :word
                parse_call head, children
            when :array
                parse_array children
            else
                STDERR.puts "[COMPILE] Unhandled #{head.inspect}"
        end
    end

    def compile_entity(ent)
        if MinatNode === ent
            compile_node ent
        else
            parse_value ent
        end
    end

    def compile()
        (
            @prefix +
            @trees.map { |e| compile_entity e } +
            @suffix
        ).join "\n\n"
    end

    # -- all of the methods -- #

    def parse_operator(op, args)
        raise_unimplemented
    end

    def parse_unary_operator(op, args)
        raise_unimplemented
    end

    def parse_value(value)
        raise_unimplemented
    end

    def parse_lambda(children)
        raise_unimplemented
    end

    def parse_call(arguments)
        raise_unimplemented
    end

    def parse_array(arguments)
        raise_unimplemented
    end
end

class MinatToRuby < MinatCompiler
    def initialize(*args)
        super(*args)
        prepend <<~EOF
            Ruby_ = lambda { |cmd|
                if cmd[0] == "."
                    lambda { |first, *args|
                        first.send cmd[1..-1], *args
                    }
                else
                    lambda { |*args|
                        send cmd, *args
                    }
                end
            }
        EOF
    end
    def op_set_global(name, val)
        "#{name.raw} = #{val}"
    end

    def parse_value(value)
        if value.type == :abstract
            "_abstract[#{value.raw.match(/\d+/)}]"
        else
            "#{value.raw}"
        end
    end

    def parse_call(fn, arguments)
        a = arguments.map { |e| compile_entity e }
        fn = case fn
            when MinatNode
                "(#{compile_entity fn})"
            else
                fn.raw
        end
        if fn == "If"
            c, i, e = a
            "((#{c}) ? (#{i}) : (#{e}))"
        else
            "#{fn}[#{a.join ", "}]"
        end
    end

    def parse_lambda(children)
        inner = children.map { |e| compile_entity e }.join ";"
        "lambda { |*args|\n_abstract=[nil,*args]\n#{inner}\n}"
    end

    def parse_array(children)
        children = children.map { |e| compile_entity e }.join ", "
        "[#{children}]"
    end

    def parse_operator(op, args)
        case op.raw
            when ":="
                name, value = args
                op_set_global name, compile_entity(value)
            when "="
                args.map { |e|
                    compile_entity(e)
                }.join "=="
            when "+", "-", "/", "*"
                args.map { |e|
                    compile_entity(e)
                }.join op.raw
        end
    end

    def parse_unary_operator(op, args)
        case op.raw
            when "-", "~", "*"
                op.raw + compile_entity(args[0])
        end
    end
end

COMPILERS = {
    ruby: MinatToRuby,
}
def compile(code, target=:ruby)
    compiler = COMPILERS[target]

    if compiler.nil?
        STDERR.puts "No such compile target #{target.inspect}"
        return
    end

    compiler.new(code).compile
end
