module ChildProcess
  class AbstractIO
    attr_reader :stderr, :stdout, :stdin

    def inherit!
      @stdout = STDOUT
      @stderr = STDERR
    end

    def stderr=(io)
      if io != :pipe
        check_type io
      end
      @stderr = io
    end

    def stdout=(io)
      if io != :pipe
        check_type io
      end
      @stdout = io
    end

    #
    # @api private
    #

    def _stdin=(io)
      check_type io
      @stdin = io
    end

    def _stdout=(io)
      check_type io
      @stdout = io
    end

    def _stderr=(io)
      check_type io
      @stderr = io
    end

    private

    def check_type(io)
      raise SubclassResponsibility, "check_type"
    end

  end
end

# vim: set sts=2 sw=2 et:
