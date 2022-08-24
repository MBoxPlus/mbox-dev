require 'minitest/autorun'


class MiniTest::Assertion
  def location
    last_before_assertion = ""
    self.backtrace.reverse_each do |s|
      if s =~ /_test.rb:/
        last_before_assertion = s
        break
      end
    end
    last_before_assertion.sub(/:in .*$/, "")
  end
end
# Module which provides support for running executables.
#
# In a class it can be used as:
#
#     extend Executable
#     executable :git
#
# This will create two methods `git` and `git!` both accept a command but
# the later will raise on non successful executions. The methods return the
# output of the command.
#
module Executable
  def assert_command(result, expect)
    if expect_code = expect[:code]
      assert_equal(expect_code, result[0], result[2].strip)
    end
    if expect_stdout = expect[:stdout]
      assert_method = expect_stdout.is_a?(Regexp) ? :assert_match : :assert_equal
      send assert_method, expect_stdout, result[1].strip
    end
    if expect_stderr = expect[:stderr]
      assert_method = expect_stderr.is_a?(Regexp) ? :assert_match : :assert_equal
      send assert_method, expect_stderr, result[2].strip
    end
    result
  end

  def mbox(command, env = {})
    expect = {}
    expect[:stdout] = env.delete(:stdout)
    expect[:stderr] = env.delete(:stderr)
    expect[:code] = env.delete(:code)
    r = Executable.mbox_command(@tmp_dir, env, command)
    if block_given?
      yield(r[0], r[1], r[2])
    end
    assert_command(r, expect)
  end

  def mbox!(command, env = {})
    expect = {}
    expect[:stdout] = env.delete(:stdout)
    expect[:stderr] = env.delete(:stderr)
    r = Executable.mbox_command(@tmp_dir, env, command)
    if block_given?
      yield(r[0], r[1], r[2])
    end
    expect[:code] = 0
    assert_command(r, expect)
  end

  include Minitest::Assertions
  def self.mbox_command(tmp_dir, env, *command)
    args = Array(command)
    env[:chdir] = "#{tmp_dir}/tests" unless env.key?(:chdir)
    args << ["--home=#{tmp_dir}/home", "--no-launcher"]
    Executable.execute_command(ENV['MBOX_CLI_PATH'], args.flatten, env)
  end

  # Creates the methods for the executable with the given name.
  #
  # @param  [Symbol] name
  #         the name of the executable.
  #
  # @return [void]
  #
  def executable(name)
    define_method(name) do |*command|
      Executable.execute_command(name, Array(command).flatten)
    end

    define_method(name.to_s + '!') do |*command|
      r = Executable.execute_command(name, Array(command).flatten)
      assert_equal(0, r[0], r[2])
      return r[1], r[2]
    end
  end

  # Executes the given command displaying it if in verbose mode.
  #
  # @param  [String] executable
  #         The binary to use.
  #
  # @param  [Array<#to_s>] command
  #         The command to send to the binary.
  #
  # @param  [Bool] raise_on_failure
  #         Whether it should raise if the command fails.
  #
  # @raise  If the executable could not be located.
  #
  # @raise  If the command fails and the `raise_on_failure` is set to true.
  #
  def self.execute_command(executable, command, **kwargs)
    executable = which!(executable)
    full_command = "#{executable} #{command.join(' ')}"

    stdout = Indenter.new
    stderr = Indenter.new

    command = [command] if command.is_a?(String)

    status = popen3(executable, command, stdout, stderr, **kwargs)
    stdout = stdout.join
    stderr = stderr.join

    return status.exitstatus, stdout, stderr
  end

  # Returns the absolute path to the binary with the given name on the current
  # `PATH`, or `nil` if none is found.
  #
  # @param  [String] program
  #         The name of the program being searched for.
  #
  # @return [String,Nil] The absolute path to the given program, or `nil` if
  #                      it wasn't found in the current `PATH`.
  #
  def self.which(program)
    program = program.to_s
    paths = ENV.fetch('PATH') { '' }.split(File::PATH_SEPARATOR)
    paths.unshift('./')
    paths.uniq!
    paths.each do |path|
      bin = File.expand_path(program, path)
      if Gem.win_platform?
        bin += '.exe'
      end
      if File.file?(bin) && File.executable?(bin)
        return bin
      end
    end
    nil
  end

  # Returns the absolute path to the binary with the given name on the current
  # `PATH`, or raises if none is found.
  #
  # @param  [String] program
  #         The name of the program being searched for.
  #
  # @return [String] The absolute path to the given program.
  #
  def self.which!(program)
    which(program).tap do |bin|
      raise "Unable to locate the executable `#{program}`" unless bin
    end
  end

  # Runs the given command, capturing the desired output.
  #
  # @param  [String] executable
  #         The binary to use.
  #
  # @param  [Array<#to_s>] command
  #         The command to send to the binary.
  #
  # @param  [Symbol] capture
  #         Whether it should raise if the command fails.
  #
  # @param  [Hash] env
  #         Environment variables to be set for the command.
  #
  # @raise  If the executable could not be located.
  #
  # @return [(String, Process::Status)]
  #         The desired captured output from the command, and the status from
  #         running the command.
  #
  def self.capture_command(executable, command, capture: :merge, env: {}, **kwargs)
    bin = which!(executable)

    require 'open3'
    command = command.map(&:to_s)
    case capture
    when :merge then Open3.capture2e(env, [bin, bin], *command, **kwargs)
    when :both then Open3.capture3(env, [bin, bin], *command, **kwargs)
    when :out then Open3.capture3(env, [bin, bin], *command, **kwargs).values_at(0, -1)
    when :err then Open3.capture3(env, [bin, bin], *command, **kwargs).drop(1)
    when :none then Open3.capture3(env, [bin, bin], *command, **kwargs).last
    end
  end

  # (see Executable.capture_command)
  #
  # @raise  If running the command fails
  #
  def self.capture_command!(executable, command, **kwargs)
    capture_command(executable, command, **kwargs).tap do |result|
      result = Array(result)
      status = result.last
      unless status.success?
        output = result[0..-2].join
        raise "#{bin} #{command.join(' ')}\n\n#{output}".strip
      end
    end
  end

  private

  def self.popen3(bin, command, stdout, stderr, **kwargs)
    require 'open3'
    Open3.popen3({"MBox" => nil}, bin, *command, **kwargs) do |i, o, e, t|
      reader(o, stdout)
      reader(e, stderr)
      i.close

      status = t.value

      o.flush
      e.flush
      sleep(0.01)

      status
    end
  end

  def self.reader(input, output)
    Thread.new do
      buf = ''
      begin
        loop do
          buf << input.readpartial(4096)
          loop do
            string, separator, buf = buf.partition(/[\r\n]/)
            if separator.empty?
              buf = string
              break
            end
            output << (string << separator)
            # puts string
          end
        end
      rescue EOFError, IOError
        output << (buf << $/) unless buf.empty?
      end
    end
  end

  #-------------------------------------------------------------------------#

  # Helper class that allows to write to an {IO} instance taking into account
  # the UI indentation level.
  #
  class Indenter < ::Array

    # @return [IO] the {IO} to which the output should be printed.
    #
    attr_reader :io

    # Init a new Indenter
    #
    # @param [IO] io @see io
    #
    def initialize(io = nil)
      @io = io
    end

    # Stores a portion of the output and prints it to the {IO} instance.
    #
    # @param  [String] value
    #         the output to print.
    #
    # @return [void]
    #
    def <<(value)
      super
      io << value if io
    end
  end
end
