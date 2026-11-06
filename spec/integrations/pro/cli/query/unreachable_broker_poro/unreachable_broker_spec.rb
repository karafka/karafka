# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# karafka query should print only its JSON envelope on stdout, also when the broker is unreachable
# and the default logger reports errors. Logs go to stderr.

require "open3"
require "json"

# The runner copies this scenario into a temporary directory, so the boot file and the license
# stub are written there
File.write("karafka.rb", <<~RUBY)
  class KarafkaApp < Karafka::App
    setup do |config|
      # Nothing listens here, so every broker call fails and librdkafka logs errors
      config.kafka = { "bootstrap.servers": "127.0.0.1:9090" }
      config.client_id = "query-unreachable"
    end
  end
RUBY

File.write("license.rb", <<~RUBY)
  module Karafka
    module License
      class << self
        def token = ENV.fetch("KARAFKA_PRO_LICENSE_TOKEN")

        def version = "1.0.0"
      end
    end
  end
RUBY

env = { "RUBYOPT" => "#{ENV["RUBYOPT"]} -r#{File.join(Dir.pwd, "license.rb")}" }
# Writes the lockfile first, so bundler does not print its resolution on the CLI stdout
_, install_output, install_status = Open3.capture3("bundle install")
raise "bundle install failed: #{install_output}" unless install_status.success?

stdout, stderr, status = Open3.capture3(env, "bundle exec karafka query cluster")

result = JSON.parse(stdout)

raise "Expected exit code 1, got #{status.exitstatus}: #{stderr}" unless status.exitstatus == 1
raise "Expected one line on stdout: #{stdout}" unless stdout.lines.size == 1
raise "Expected a failed envelope: #{stdout}" unless result["ok"] == false && result["error"] == "failed"
raise "Expected logs on stderr" if stderr.empty?
