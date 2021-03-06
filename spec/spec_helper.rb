$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'childprocess'
require 'rspec'
require 'tempfile'
require 'socket'
require 'stringio'

module ChildProcessSpecHelper
  EXIT_TIMEOUT = 10
  RUBY = defined?(Gem) ? Gem.ruby : 'ruby'

  def ruby_process(*args)
    @process = ChildProcess.build(RUBY , *args)
  end

  # Wait on process using poll_for_exit
  def wait_on_process(kwds={})
    timeout = kwds.fetch(:timeout, EXIT_TIMEOUT)
    fail_on_error = kwds.fetch(:fail_on_error, true)

    exit_code = @process.poll_for_exit(timeout)
    if fail_on_error
      check_exit_code(exit_code)
    end
    return exit_code
  end

  def stop_process(kwds={})
    timeout = kwds.fetch(:timeout, EXIT_TIMEOUT)

    @process.stop(timeout)
  end

  def sleeping_ruby
    ruby_process("-e", "sleep")
  end

  def ignored(signal)
    code = <<-RUBY
      trap(#{signal.inspect}, "IGNORE")
      sleep
    RUBY

    ruby_process tmp_script(code)
  end

  def write_env(path)
    code = <<-RUBY
      File.open(#{path.inspect}, "w") { |f| f << ENV.inspect }
    RUBY

    ruby_process tmp_script(code)
  end

  def write_argv(path, *args)
    code = <<-RUBY
      File.open(#{path.inspect}, "w") { |f| f << ARGV.inspect }
    RUBY

    ruby_process(tmp_script(code), *args)
  end

  def write_pid(path)
    code = <<-RUBY
      File.open(#{path.inspect}, "w") { |f| f << Process.pid }
    RUBY

    ruby_process tmp_script(code)
  end

  def exit_with(exit_code)
    ruby_process(tmp_script("exit(#{exit_code})"))
  end

  def with_env(hash)
    hash.each { |k,v| ENV[k] = v }
    begin
      yield
    ensure
      hash.each_key { |k| ENV[k] = nil }
    end
  end

  def tmp_script(code)
    # use an ivar to avoid GC
    @tf = Tempfile.new("childprocess-temp")
    @tf << code
    @tf.close

    puts code if $DEBUG

    @tf.path
  end

  def within(seconds, &blk)
    end_time   = Time.now + seconds
    ok         = false
    last_error = nil

    until ok || Time.now >= end_time
      begin
        ok = yield
      rescue RSpec::Expectations::ExpectationNotMetError => last_error
      end
    end

    raise last_error unless ok
  end

  def ruby(code)
    ruby_process(tmp_script(code))
  end

  # Verify that process exited cleanly
  def check_exit_code(exit_code)
    if exit_code != 0
      msg = "Process failed with code #{exit_code}"
      if not @process.io.stderr.nil?
        msg += ": #{@process.io.stderr.read()}"
      end
      raise RuntimeError, msg
    end
  end

end # ChildProcessSpecHelper

Thread.abort_on_exception = true

RSpec.configure do |config|
  config.include(ChildProcessSpecHelper)
  config.after(:each) {
    @process && @process.alive? && @process.stop
  }
end

# vim: set sts=2 sw=2 et:
