# frozen_string_literal: true

# Karafka install should run and after that, we should be able to run it without any problems

require 'tmpdir'
require 'fileutils'
require 'open3'
require 'logger'

spec_dir = File.expand_path(__dir__)

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

# Removes the Ruby def from the Gemfile as preview versions cause problems.
#
# @param file_path [String] path to a Gemfile from which we should remove Ruby def
def remove_ruby_def(file_path)
  lines = File.readlines(file_path)

  filtered_lines = lines.reject { |line| line.start_with?('ruby "') }

  File.open(file_path, 'w') do |file|
    file.puts(filtered_lines)
  end
end

Dir.mktmpdir do |dir|
  FileUtils.cp(
    File.join(spec_dir, 'Gemfile'),
    File.join(dir, 'Gemfile')
  )

  Bundler.with_unbundled_env do
    be_install = cmd(dir, 'bundle install')
    assert_equal 0, be_install[1], be_install[0]

    re_new = cmd(dir, 'bundle exec rails new rapp --api')
    assert_equal 0, re_new[1], re_new[0]

    mv_app = cmd(dir, 'mv ./rapp/** ./')
    assert_equal 0, mv_app[1], mv_app[0]

    # rails new has its own Gemfile to which we need to add karafka once more
    File.open("#{dir}/Gemfile", 'a') do |f|
      f.puts 'gem "karafka", path: ENV.fetch("KARAFKA_GEM_DIR"), require: true'
      f.puts 'gem "bigdecimal"'
      f.puts 'gem "logger"'
      f.puts 'gem "mutex_m"'
    end

    file_path = "#{dir}/config/application.rb"
    existing_content = File.read(file_path)
    new_first_line = "require 'logger'\n"
    new_content = new_first_line + existing_content
    File.write(file_path, new_content)

    remove_ruby_def("#{dir}/Gemfile")

    be_install = cmd(dir, 'bundle install')
    assert_equal 0, be_install[1], be_install[0]

    kr_install = cmd(dir, 'bundle exec karafka install')
    assert_equal 0, kr_install[1], kr_install[0]

    # Give it enough time to start and stop
    kr_run = cmd(dir, 'timeout --preserve-status 10 bundle exec karafka server')
    assert_equal 0, kr_run[1], kr_run[0]
  end
end
