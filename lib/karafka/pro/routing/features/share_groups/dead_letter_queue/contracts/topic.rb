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
    module Routing
      module Features
        module ShareGroups
          class DeadLetterQueue < Base
            # This feature validation contracts
            module Contracts
              # Rules around dead letter queue settings
              class Topic < Karafka::Contracts::Base
                configure do |config|
                  config.error_messages = YAML.safe_load_file(
                    File.join(Karafka.gem_root, "config", "locales", "errors.yml")
                  ).fetch("en").fetch("validations").fetch("routing").fetch("topic")
                end

                nested :dead_letter_queue do
                  required(:active) { |val| [true, false].include?(val) }
                  required(:max_retries) { |val| val.is_a?(Integer) && val >= 0 }

                  required(:dispatch_method) do |val|
                    %i[produce_async produce_sync].include?(val)
                  end
                end

                # Validate topic name only if dlq is active
                virtual do |data, errors|
                  next unless errors.empty?

                  dead_letter_queue = data[:dead_letter_queue]

                  next unless dead_letter_queue[:active]

                  topic = dead_letter_queue[:topic]
                  topic_regexp = Karafka::Contracts::TOPIC_REGEXP

                  # When topic is set to false, it means we just want to reject without dispatch
                  next if topic == false
                  next if topic.is_a?(String) && topic_regexp.match?(topic)

                  [[%i[dead_letter_queue topic], :format]]
                end
              end
            end
          end
        end
      end
    end
  end
end
