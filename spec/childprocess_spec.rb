require File.expand_path('../spec_helper', __FILE__)

describe ChildProcess do
  it "returns self when started" do
    process = sleeping_ruby

    process.start.should == process
    process.should be_started
  end

  it "knows if the process crashed" do
    process = exit_with(1).start
    wait_on_process()

    process.should be_crashed
  end

  it "knows if the process didn't crash" do
    process = exit_with(0).start
    wait_on_process

    process.should_not be_crashed
  end

  it "escalates if TERM is ignored" do
    process = ignored('TERM').start
    process.stop
    process.should be_exited
  end

  it "accepts a timeout argument to #stop" do
    process = sleeping_ruby.start
    process.stop(EXIT_TIMEOUT)
  end

  it "lets child process inherit the environment of the current process" do
    Tempfile.open("env-spec") do |file|
      with_env('INHERITED' => 'yes') do
        process = write_env(file.path).start
        wait_on_process
      end

      file.rewind
      child_env = eval(file.read)
      child_env['INHERITED'].should == 'yes'
    end
  end

  it "passes arguments to the child" do
    args = ["foo", "bar"]

    Tempfile.open("argv-spec") do |file|
      process = write_argv(file.path, *args).start
      wait_on_process

      file.rewind
      file.read.should == args.inspect
    end
  end

  it "lets a detached child live on" do
    pending "how do we spec this?"
  end

  it "can redirect stdout, stderr" do
    process = ruby(<<-CODE)
      [STDOUT, STDERR].each_with_index do |io, idx|
        io.sync = true
        io.puts idx
      end

      sleep 0.2
    CODE

    out = Tempfile.new("stdout-spec")
    err = Tempfile.new("stderr-spec")

    begin
      process.io.stdout = out
      process.io.stderr = err

      process.start
      process.io.stdin.should be_nil
      wait_on_process

      out.rewind
      err.rewind

      out.read.should == "0\n"
      err.read.should == "1\n"
    ensure
      out.close
      err.close
    end
  end

  it "can redirect stdout, stderr to pipes" do
    process = ruby(<<-CODE)
      [STDOUT, STDERR].each_with_index do |io, idx|
        io.sync = true
        io.puts idx
      end
    CODE

    process.io.stdout = :pipe
    process.io.stderr = :pipe
    process.start()
    wait_on_process()

    stdout = process.io.stdout.read()
    stderr = process.io.stderr.read()
    stdout.should == "0\n"
    stderr.should == "1\n"
  end

  it "can write to stdin if duplex = true" do
    process = ruby(<<-CODE)
      puts(STDIN.gets.chomp)
    CODE

    out = Tempfile.new("duplex")

    begin
      process.io.stdout = out
      process.io.stderr = out
      process.duplex = true

      process.start
      process.io.stdin.puts "hello world"
      process.io.stdin.close # JRuby seems to need this

      wait_on_process

      out.rewind
      out.read.should == "hello world\n"
    ensure
      out.close
    end
  end

  it "can set close-on-exec when IO is inherited" do
    server = TCPServer.new("localhost", 4433)
    ChildProcess.close_on_exec server

    process = sleeping_ruby
    process.io.inherit!

    process.start
    sleep 0.5 # give the forked process a chance to exec() (which closes the fd)

    server.close
    lambda { TCPServer.new("localhost", 4433).close }.should_not raise_error
  end

  it "knows the process' exit code" do
    process = exit_with(0).start
    wait_on_process
    process.exit_code.should == 0
  end

  it "returns the exit code from poll_for_exit" do
    exit_with(1).start
    wait_on_process().should == 1
  end

  it "can handle whitespace and special characters in arguments" do
    args = ["foo bar", 'foo\bar']

    Tempfile.open("argv-spec") do |file|
      write_argv(file.path, *args).start
      wait_on_process()

      file.rewind
      file.read.should == args.inspect
    end
  end

  describe "#poll_for_exit" do
    it "raises TimeoutError upon timeout" do
      process = sleeping_ruby.start
      expect { wait_on_process(0.1) }.to raise_error(ChildProcess::TimeoutError)
    end
  end

end
