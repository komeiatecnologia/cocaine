require 'spec_helper'

def with_exitstatus_returning(code)
  saved_exitstatus = $?.nil? ? 0 : $?.exitstatus
  begin
    `ruby -e 'exit #{code.to_i}'`
    yield
  ensure
    `ruby -e 'exit #{saved_exitstatus.to_i}'`
  end
end

describe Cocaine::CommandLine do
  before do
    Cocaine::CommandLine.path = nil
    File.stubs(:exist?).with("/dev/null").returns(true)
  end

  it "takes a command and parameters and produce a shell command for bash" do
    cmd = Cocaine::CommandLine.new("convert", "a.jpg b.png", :swallow_stderr => false)
    cmd.command.should == "convert a.jpg b.png"
  end

  it "can set a default path and produce commands with that path" do
    Cocaine::CommandLine.path = "/opt/bin"
    cmd = Cocaine::CommandLine.new("convert", "a.jpg b.png", :swallow_stderr => false)
    cmd.command.should == "/opt/bin/convert a.jpg b.png"
  end

  it "can interpolate quoted variables into the parameters" do
    cmd = Cocaine::CommandLine.new("convert",
                                     ":one :{two}",
                                     :one => "a.jpg",
                                     :two => "b.png",
                                     :swallow_stderr => false)
    cmd.command.should == "convert 'a.jpg' 'b.png'"
  end

  it "quotes command line options differently if we're on windows" do
    File.stubs(:exist?).with("/dev/null").returns(false)
    cmd = Cocaine::CommandLine.new("convert",
                                     ":one :{two}",
                                     :one => "a.jpg",
                                     :two => "b.png",
                                     :swallow_stderr => false)
    cmd.command.should == 'convert "a.jpg" "b.png"'
  end

  it "can quote and interpolate dangerous variables" do
    cmd = Cocaine::CommandLine.new("convert",
                                     ":one :two",
                                     :one => "`rm -rf`.jpg",
                                     :two => "ha'ha.png",
                                     :swallow_stderr => false)
    cmd.command.should == "convert '`rm -rf`.jpg' 'ha'\\''ha.png'"
  end

  it "can quote and interpolate dangerous variables even on windows" do
    File.stubs(:exist?).with("/dev/null").returns(false)
    cmd = Cocaine::CommandLine.new("convert",
                                     ":one :two",
                                     :one => "`rm -rf`.jpg",
                                     :two => "ha'ha.png",
                                     :swallow_stderr => false)
    cmd.command.should == %{convert "`rm -rf`.jpg" "ha'ha.png"}
  end

  it "allows colons in parameters" do
    cmd = Cocaine::CommandLine.new("convert", "'a.jpg' xc:black 'b.jpg'", :swallow_stderr => false)
    cmd.command.should == "convert 'a.jpg' xc:black 'b.jpg'"
  end

  it "adds redirection to get rid of stderr in bash" do
    File.stubs(:exist?).with("/dev/null").returns(true)
    cmd = Cocaine::CommandLine.new("convert",
                                     "a.jpg b.png",
                                     :swallow_stderr => true)

    cmd.command.should == "convert a.jpg b.png 2>/dev/null"
  end

  it "adds redirection to get rid of stderr in cmd.exe" do
    File.stubs(:exist?).with("/dev/null").returns(false)
    cmd = Cocaine::CommandLine.new("convert",
                                     "a.jpg b.png",
                                     :swallow_stderr => true)

    cmd.command.should == "convert a.jpg b.png 2>NUL"
  end

  it "raises if trying to interpolate :swallow_stderr or :expected_outcodes" do
    cmd = Cocaine::CommandLine.new("convert",
                                     ":swallow_stderr :expected_outcodes",
                                     :swallow_stderr => false,
                                     :expected_outcodes => [0, 1])

    lambda do
      cmd.command
    end.should raise_error(Cocaine::CommandLineError)
  end

  it "runs the #command it's given and return the output" do
    cmd = Cocaine::CommandLine.new("convert", "a.jpg b.png", :swallow_stderr => false)
    cmd.class.stubs(:"`").with("convert a.jpg b.png").returns(:correct_value)
    with_exitstatus_returning(0) do
      cmd.run.should == :correct_value
    end
  end

  it "raises a CommandLineError if the result code isn't expected" do
    cmd = Cocaine::CommandLine.new("convert", "a.jpg b.png", :swallow_stderr => false)
    cmd.class.stubs(:"`").with("convert a.jpg b.png").returns(:correct_value)
    with_exitstatus_returning(1) do
      lambda do
        cmd.run
      end.should raise_error(Cocaine::CommandLineError)
    end
  end

  it "does not raise a CommandLineError if the result code is expected" do
    cmd = Cocaine::CommandLine.new("convert",
                                     "a.jpg b.png",
                                     :expected_outcodes => [0, 1],
                                     :swallow_stderr => false)
    cmd.class.stubs(:"`").with("convert a.jpg b.png").returns(:correct_value)
    with_exitstatus_returning(1) do
      lambda do
        cmd.run
      end.should_not raise_error
    end
  end

  it "detects that the system is unix or windows based on presence of /dev/null" do
    File.stubs(:exist?).returns(true)
    Cocaine::CommandLine.unix?.should == true
  end

  it "detects that the system is not unix or windows based on absence of /dev/null" do
    File.stubs(:exist?).returns(false)
    Cocaine::CommandLine.unix?.should_not == true
  end
end
