# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# When we have strict_declarative_topics set to true, we should ensure all non-pattern definitions
# of topics have their declarative references

setup_karafka do |config|
  config.strict_declarative_topics = true
end

ARGV[0] = 'info'

def draw_and_validate(valid:, &block)
  guarded = false

  begin
    draw_routes(create_topics: false) do
      instance_eval(&block)
    end

    Karafka::Cli.start
  rescue Karafka::Errors::InvalidConfigurationError
    guarded = true
  end

  valid ? assert(!guarded) : assert(guarded)

  Karafka::App.routes.clear
end

draw_and_validate(valid: false) do
  topic 'a' do
    consumer Class.new
    config(active: false)
  end
end

draw_and_validate(valid: true) do
  topic 'a' do
    consumer Class.new
  end
end

draw_and_validate(valid: false) do
  topic 'a' do
    consumer Class.new
    dead_letter_queue(topic: 'dlq')
  end
end

draw_and_validate(valid: true) do
  topic 'a' do
    consumer Class.new
    dead_letter_queue(topic: 'dlq')
  end

  topic 'dlq' do
    active(false)
  end
end

draw_and_validate(valid: false) do
  topic 'a' do
    consumer Class.new
    dead_letter_queue(topic: 'dlq')
  end

  topic 'dlq' do
    active(false)
    config(active: false)
  end
end

draw_and_validate(valid: false) do
  pattern(/a/) do
    consumer Class.new
    dead_letter_queue(topic: 'dlq')
  end

  topic 'dlq' do
    active(false)
    config(active: false)
  end
end

draw_and_validate(valid: false) do
  pattern(/a/) do
    consumer Class.new
    dead_letter_queue(topic: 'dlq')
  end
end

draw_and_validate(valid: true) do
  pattern(/a/) do
    consumer Class.new
  end
end

draw_and_validate(valid: true) do
  pattern('a', /a/) do
    consumer Class.new
  end
end

# When no strict declaratives
Karafka::App.config.strict_declarative_topics = false

draw_and_validate(valid: true) do
  topic 'a' do
    consumer Class.new
    dead_letter_queue(topic: 'dlq')
  end

  topic 'dlq' do
    active(false)
    config(active: false)
  end
end
