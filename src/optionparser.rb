require 'optparse'

class MinatOptionParser
    FILENAME = File.basename __FILE__
    def self.parse(args)
        options = {}

        parser = OptionParser.new { |opts|
            opts.program_name = FILENAME
            opts.banner = "Usage: #{FILENAME} [options]"

            opts.separator ""
            opts.separator "[options]"

            opts.on(
                "-a", "--ast",
                "Displays the AST of the input"
            ) do |v|
                options[:ast] = v
            end

            opts.on(
                "-c", "--compile",
                "Displays the AST of the input"
            ) do |v|
                options[:compile] = v
            end

            opts.on(
                "-s", "--shunt",
                "Displays the result of shunting the input"
            ) do |v|
                options[:shunt] = v
            end

            opts.on(
                "-t", "--tokenize",
                "Displays the result of tokenizing the input"
            ) do |v|
                options[:tokenize] = v
            end

            opts.on(
                "-r", "--run",
                "Runs the program"
            ) do |v|
                options[:run] = v
            end

            opts.on(
                "-i", "--STDIN [TYPE]",
                String,
                "Reads the program from STDIN, until [TYPE]"
            ) do |v=nil|
                options[:stdin] = v
            end

            opts.on(
                "-e", "--execute CODE",
                String,
                "Displays the result of tokenizing the input"
            ) do |v|
                options[:program] = v
            end

            opts.on_tail(
                "-h", "--help",
                "Show this help message"
            ) do |v|
                puts opts
                exit
            end
        }
        parser.parse!(args)
        if options.empty? && args.empty?
            puts parser
            exit
        end
        options
    end
end
