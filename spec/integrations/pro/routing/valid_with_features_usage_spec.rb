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

# Karafka should auto-load all the routing features

setup_karafka

draw_routes(create_topics: false) do
  subscription_group do
    topic 'topic1' do
      consumer Class.new
      dead_letter_queue(topic: 'xyz', max_retries: 2)
      manual_offset_management true
      long_running_job true
    end
  end

  topic 'topic2' do
    consumer Class.new
  end
end

assert Karafka::App.consumer_groups.first.topics.first.dead_letter_queue?
assert Karafka::App.consumer_groups.first.topics.first.manual_offset_management?
assert Karafka::App.consumer_groups.first.topics.first.long_running_job?
assert !Karafka::App.consumer_groups.first.topics.last.dead_letter_queue?
assert !Karafka::App.consumer_groups.first.topics.last.manual_offset_management?
assert !Karafka::App.consumer_groups.first.topics.last.long_running_job?
