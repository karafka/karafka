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

module Karafka
  module Pro
    module Admin
      class DeadLetterQueues < Karafka::Admin
        # Contracts for dead letter queue operations
        module Contracts
          # Contract for dead letter queue copy parameters
          class Copy < Karafka::Pro::Contracts::Base
            configure do |config|
              config.error_messages = YAML.safe_load_file(
                File.join(Karafka.gem_root, "config", "locales", "pro_errors.yml")
              ).fetch("en").fetch("validations").fetch("admin_dead_letter_queues_copy")
            end

            required(:topic_name) { |val| val.is_a?(String) && !val.empty? }
            required(:target_topic_name) { |val| val.nil? || (val.is_a?(String) && !val.empty?) }
            required(:start_offset) { |val| val.is_a?(Time) || (val.is_a?(Integer) && val >= 0) }
            required(:end_offset) { |val| val.nil? || (val.is_a?(Integer) && val >= 0) }

            required(:partitions) do |val|
              next true if val.nil?
              next false unless val.is_a?(Array) && !val.empty?

              val.all? { |partition| partition.is_a?(Integer) && partition >= 0 } &&
                val.uniq.size == val.size
            end

            # Karafka.producer dispatches to the app cluster, not to the custom one
            virtual do |data, errors|
              next unless errors.empty?
              next unless data.fetch(:custom_kafka)
              next unless data.fetch(:producer).nil?

              [[%w[producer], :required_with_custom_kafka]]
            end
          end
        end
      end
    end
  end
end
