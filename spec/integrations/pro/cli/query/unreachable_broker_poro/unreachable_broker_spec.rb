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

env = { "RUBYOPT" => "-r#{File.join(Dir.pwd, "license.rb")}" }
stdout, stderr, status = Open3.capture3(env, "bundle exec karafka query cluster")

result = JSON.parse(stdout)

raise "Expected exit code 1, got #{status.exitstatus}: #{stderr}" unless status.exitstatus == 1
raise "Expected one line on stdout: #{stdout}" unless stdout.lines.size == 1
raise "Expected a failed envelope: #{stdout}" unless result["ok"] == false && result["error"] == "failed"
raise "Expected logs on stderr" if stderr.empty?
