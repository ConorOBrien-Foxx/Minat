require_relative "src/ast.rb"
require_relative "src/compiler.rb"
require_relative "src/optionparser.rb"
require_relative "src/shunter.rb"
require_relative "src/tokenizer.rb"

options = MinatOptionParser.parse(ARGV)

def read_program(options)
    if options.has_key? :stdin
        STDIN.gets options[:stdin]
    else
        options[:program] || File.read(ARGV[0], encoding: "UTF-8") rescue ""
    end
end

program = read_program options

if options[:shunt]
    puts "[shunting]"
    puts shunt(program).map(&:to_s)
end

if options[:tokenize]
    puts "[tokenizing]"
    puts tokenize(program).map(&:to_s)
end

if options[:ast]
    puts "[ast]"
    puts ast(program).map(&:to_s)
end

if options[:compile]
    puts "[compiled]"
    puts compile program
end


if options[:run]
    program = File.read("lib/std.mnt") + program
    comp = compile program
    eval comp
end
