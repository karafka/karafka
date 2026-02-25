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

# Karafka should allow for multiplexing subscription group

setup_karafka do |config|
  config.strict_topics_namespacing = false
end

failed = false

SG_UUID = SecureRandom.uuid

begin
  draw_routes(create_topics: false) do
    consumer_group :test do
      subscription_group SG_UUID do
        multiplexing(min: 2, max: 5)

        topic "namespace_collision" do
          consumer Class.new
        end
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert_equal 5, Karafka::App.routes.first.subscription_groups.size

Karafka::App.routes.first.subscription_groups.each_with_index do |sg, i|
  assert sg.id.include?("#{SG_UUID}_#{i}")
  assert_equal sg.name, SG_UUID
end

assert !failed
