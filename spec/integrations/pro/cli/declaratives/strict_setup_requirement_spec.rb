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

# When we have strict_declarative_topics set to true, we should ensure all non-pattern definitions
# of topics have their declarative references. Pattern (regexp) topics are virtual and excluded.
# Declarative definitions now live independently in the declaratives repository, so a routed topic
# is "covered" only when it has an active declaration there.

setup_karafka do |config|
  config.strict_declarative_topics = true
end

ARGV[0] = "info"

# @param valid [Boolean] whether strict validation is expected to pass
# @param declaratives [Hash] topic name => active flag to declare before drawing routes
# @param block [Proc] routing definition
def draw_and_validate(valid:, declaratives: {}, &block)
  guarded = false

  declaratives.each do |name, active|
    Karafka::App.declaratives.draw do
      topic(name) { active(active) }
    end
  end

  begin
    draw_routes(create_topics: false) do
      instance_eval(&block)
    end

    Karafka::Cli.start
  rescue Karafka::Errors::InvalidConfigurationError
    guarded = true
  end

  valid ? assert(!guarded) : assert(guarded)

  clear_app_draws
end

# 'a' routed but not declared -> guards
draw_and_validate(valid: false) do
  topic "a" do
    consumer Class.new
  end
end

# 'a' routed and declared active -> ok
draw_and_validate(valid: true, declaratives: { "a" => true }) do
  topic "a" do
    consumer Class.new
  end
end

# 'a' declared but its DLQ 'dlq' is not -> guards
draw_and_validate(valid: false, declaratives: { "a" => true }) do
  topic "a" do
    consumer Class.new
    dead_letter_queue(topic: "dlq")
  end
end

# both 'a' and 'dlq' declared active -> ok
draw_and_validate(valid: true, declaratives: { "a" => true, "dlq" => true }) do
  topic "a" do
    consumer Class.new
    dead_letter_queue(topic: "dlq")
  end
end

# 'dlq' declared inactive -> guards
draw_and_validate(valid: false, declaratives: { "a" => true, "dlq" => false }) do
  topic "a" do
    consumer Class.new
    dead_letter_queue(topic: "dlq")
  end
end

# Pattern topic is excluded, but its DLQ 'dlq' is still required and is not declared -> guards
draw_and_validate(valid: false) do
  pattern(/a/) do
    consumer Class.new
    dead_letter_queue(topic: "dlq")
  end
end

# Pattern-only routing has no non-pattern topics to declare -> ok
draw_and_validate(valid: true) do
  pattern(/a/) do
    consumer Class.new
  end
end

# Named pattern is still a virtual pattern topic -> excluded -> ok
draw_and_validate(valid: true) do
  pattern("a", /a/) do
    consumer Class.new
  end
end

# When strict declaratives is off, missing declarations are acceptable
Karafka::App.config.strict_declarative_topics = false

draw_and_validate(valid: true, declaratives: { "a" => true, "dlq" => false }) do
  topic "a" do
    consumer Class.new
    dead_letter_queue(topic: "dlq")
  end
end
