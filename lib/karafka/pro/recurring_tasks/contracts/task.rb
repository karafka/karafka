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
        # Ensures that task details are as expected
        class Task < Karafka::Contracts::Base
          configure do |config|
            config.error_messages = YAML.safe_load_file(
              File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
            ).fetch('en').fetch('validations').fetch('recurring_tasks')
          end

          # Regexp to ensure all tasks ids are URL safe
          ID_REGEXP = /\A[a-zA-Z0-9_-]{1,}\z/

          required(:id) { |val| val.is_a?(String) && val.match?(ID_REGEXP) }
          required(:cron) { |val| val.is_a?(String) && val.length.positive? }
          required(:enabled) { |val| [true, false].include?(val) }
          required(:changed) { |val| [true, false].include?(val) }
          required(:previous_time) { |val| val.is_a?(Numeric) || val.is_a?(Time) }
        end
      end
    end
  end
end
