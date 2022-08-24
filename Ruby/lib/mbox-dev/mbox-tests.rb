require 'minitest/autorun'
require 'minitest/hooks/test'
require 'tmpdir'
require 'fileutils'
require_relative 'executable'
require 'json'
require 'minitest/rg'

class MBoxErrorCode
  USER=254
end

class MBoxTests < MiniTest::Test
  include Minitest::Hooks
  extend Executable
  include Executable

  def before_all
    super
    @tmp_root = Dir.mktmpdir("MBoxTest-")
    @cache_dir = @tmp_root + "/caches"
    FileUtils.mkdir_p @cache_dir
  end

  def setup
    super
    @tmp_dir = @tmp_root + "/" + (0...8).map { (65 + rand(26)).chr }.join
    @home_dir = @tmp_dir + "/home"
    FileUtils.mkdir_p @home_dir
    FileUtils.mkdir_p @home_dir + "/.mbox"

    @tests_dir = @tmp_dir + "/tests"
    FileUtils.mkdir_p @tests_dir
    # puts "TMP DIR: #{@tmp_dir}"
  end

  def teardown
    super
    unless self.failures.empty?
      puts ""
      puts "::group::#{self.name}"
      output_verbose_log
      puts "::endgroup::"
    end
    FileUtils.rm_rf(@tmp_dir)
  end

  def output_verbose_log
  end

  def assert_contains_file(dir, files)
    files = [files] if files.is_a?(String)
    all_files = Dir.children(dir)
    files.each do |file|
      assert all_files.include?(file), "#{dir}: #{all_files} NOT contains `#{file}`."
    end
  end

  def assert_not_contains_file(dir, files)
    files = [files] if files.is_a?(String)
    all_files = Dir.children(dir)
    files.each do |file|
      assert !all_files.include?(file), "#{dir}: #{all_files} should NOT contains `#{file}`."
    end
  end
end
