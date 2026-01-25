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

module Karafka
  module Pro
    module RecurringTasks
      # Recurring Tasks related contracts
      module Contracts
        # Makes sure, all the expected config is defined as it should be
        class Config < Karafka::Contracts::Base
          configure do |config|
            config.error_messages = YAML.safe_load_file(
              File.join(Karafka.gem_root, "config", "locales", "pro_errors.yml")
            ).fetch("en").fetch("validations").fetch("setup").fetch("config")
          end

          nested(:recurring_tasks) do
            required(:consumer_class) { |val| val < Karafka::BaseConsumer }
            required(:deserializer) { |val| !val.nil? }
            required(:logging) { |val| [true, false].include?(val) }
            # Do not allow to run more often than every 5 seconds
            required(:interval) { |val| val.is_a?(Integer) && val >= 1_000 }
            required(:group_id) do |val|
              val.is_a?(String) && Karafka::Contracts::TOPIC_REGEXP.match?(val)
            end

            nested(:topics) do
              nested(:schedules) do
                required(:name) do |val|
                  val.is_a?(String) && Karafka::Contracts::TOPIC_REGEXP.match?(val)
                end
              end

              nested(:logs) do
                required(:name) do |val|
                  val.is_a?(String) && Karafka::Contracts::TOPIC_REGEXP.match?(val)
                end
              end
            end
          end
        end
      end
    end
  end
end
