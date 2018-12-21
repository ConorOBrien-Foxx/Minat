class MinatError < StandardError
    def initialize(message="Something has gone horribly wrong", source=nil)
        @message = message
        @source = source
        if @source
            @message = "[#@source] #@message"
        end
        super(@message)
    end
end

class MinatSyntaxError < MinatError
end
