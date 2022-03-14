# frozen_string_literal: true

# Karafka install should run and after that, we should be able to run it without any problems

require 'tmpdir'
require 'fileutils'
require 'open3'

spec_dir = File.expand_path(__dir__)

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
    File.join(spec_dir, 'Gemfile'),
    File.join(dir, 'Gemfile')
  )

  Bundler.with_unbundled_env do
    assert_equal 0, cmd(dir, 'bundle install')
    assert_equal 0, cmd(dir, 'rails new rapp --api')
    assert_equal 0, cmd(dir, 'mv ./rapp/** ./')

    # rails new has its own Gemfile to which we need to add karafka once more
    File.open("#{dir}/Gemfile", 'a') do |f|
      f.puts 'gem "karafka", path: ENV.fetch("KARAFKA_GEM_DIR"), require: true'
    end

    assert_equal 0, cmd(dir, 'bundle install')
    assert_equal 0, cmd(dir, 'bundle exec karafka install')
    # Give it enough time to start and stop
    assert_equal 0, cmd(dir, 'timeout --preserve-status 10 bundle exec karafka server')
  end
end
