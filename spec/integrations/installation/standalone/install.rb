# frozen_string_literal: true

# Karafka install should run and after that, we should be able to run it without any problems

require 'tmpdir'
require 'fileutils'
require 'open3'

current_dir = File.expand_path(__dir__)

# Runs a given command in a given dir and returns its exit code
# @param dir [String]
# @param cmd [String]
# @return [Integer]
def cmd(dir, cmd)
  _, _, status = Open3.capture3("cd #{dir} && KARAFKA_GEM_DIR=#{ENV['KARAFKA_GEM_DIR']} #{cmd}")
  status.exitstatus
end

Dir.mktmpdir do |dir|
  FileUtils.cp(
    File.join(current_dir, 'Gemfile'),
    File.join(dir, 'Gemfile')
  )

  Bundler.with_unbundled_env do
    assert_equal 0, cmd(dir, 'bundle install')
    assert_equal 0, cmd(dir, 'bundle exec karafka install')
    assert_equal 0, cmd(dir, 'timeout --preserve-status 3 bundle exec karafka server')
  end
end
