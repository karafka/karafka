# frozen_string_literal: true

# Karafka install with `--share_groups` should also generate the `ApplicationShareConsumer` base,
# and the app should boot with it, as the boot file eager loads `app/consumers`

require "tmpdir"
require "fileutils"
require "open3"

current_dir = File.expand_path(__dir__)

# Runs a given command in a given dir and returns its exit code
# @param dir [String]
# @param cmd [String]
# @return [Array<String, Integer>]
def cmd(dir, cmd)
  stdout, stderr, status = Open3.capture3(
    "cd #{dir} && KARAFKA_GEM_DIR=#{ENV.fetch("KARAFKA_GEM_DIR", nil)} #{cmd}"
  )
  ["#{stdout}\n#{stderr}", status.exitstatus]
end

Dir.mktmpdir do |dir|
  FileUtils.cp(
    File.join(current_dir, "Gemfile"),
    File.join(dir, "Gemfile")
  )

  Bundler.with_unbundled_env do
    be_install = cmd(dir, "bundle install")
    assert_equal 0, be_install[1], be_install[0]

    kr_install = cmd(dir, "bundle exec karafka install --share_groups")
    assert_equal 0, kr_install[1], kr_install[0]

    share_consumer_path = File.join(dir, "app/consumers/application_share_consumer.rb")
    assert File.exist?(share_consumer_path), kr_install[0]

    share_consumer = File.read(share_consumer_path)
    assert share_consumer.include?("class ApplicationShareConsumer < Karafka::ShareConsumer"), share_consumer

    kr_run = cmd(dir, "timeout --preserve-status 10 bundle exec karafka server")
    assert_equal 0, kr_run[1], kr_run[0]
  end
end
