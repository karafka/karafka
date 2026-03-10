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

# We should be able to reconfigure recurring tasks topics also via the direct config API
# This allows us to reconfigure things granularly.

setup_karafka(allow_errors: true)

code = nil

# Creating happens in a background thread and we want to catch errors, hence we need to trigger
# the creation inline
draw_routes(create_topics: false) do
  recurring_tasks(true) do |schedules_topic, logs_topic|
    schedules_topic.config.replication_factor = 2
    logs_topic.config.replication_factor = 2
  end
end

begin
  Karafka::Cli::Topics::Create.new.call
rescue Karafka::Errors::CommandValidationError => e
  code = e.cause.code
end

assert_equal :invalid_replication_factor, code
