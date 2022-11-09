# frozen_string_literal: true

# Karafka install should run and after that, we should be able to run it without any problems

require 'tmpdir'
require 'fileutils'
require 'open3'

current_dir = File.expand_path(__dir__)

# Runs a given command in a given dir and returns its exit code
# @param dir [String]
# @param cmd [String]
# @return [Array<String, Integer>]
def cmd(dir, cmd)
  stdout, stderr, status = Open3.capture3(
    "cd #{dir} && KARAFKA_GEM_DIR=#{ENV['KARAFKA_GEM_DIR']} #{cmd}"
  )
  ["#{stdout}\n#{stderr}", status.exitstatus]
end

Dir.mktmpdir do |dir|
  FileUtils.cp(
    File.join(current_dir, 'Gemfile'),
    File.join(dir, 'Gemfile')
  )

  Bundler.with_unbundled_env do
    be_install = cmd(dir, 'bundle install')
    assert_equal 0, be_install[1], be_install[0]

    kr_install = cmd(dir, 'bundle exec karafka install')
    assert_equal 0, kr_install[1], kr_install[0]

    kr_run = cmd(dir, 'timeout --preserve-status 10 bundle exec karafka server')
    assert_equal 0, kr_run[1], kr_run[0]
  end
end
