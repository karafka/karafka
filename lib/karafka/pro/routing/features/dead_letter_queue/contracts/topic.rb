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
    module Routing
      module Features
        class DeadLetterQueue < Base
          # Namespace for DLQ contracts
          module Contracts
            # Extended rules for dead letter queue settings
            class Topic < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load_file(
                  File.join(Karafka.gem_root, "config", "locales", "pro_errors.yml")
                ).fetch("en").fetch("validations").fetch("routing").fetch("topic")
              end

              nested(:dead_letter_queue) do
                # We use strategy based DLQ for every case in Pro
                # For default (when no strategy) a default `max_retries` based strategy is used
                required(:strategy) { |val| val.respond_to?(:call) }
              end

              # Make sure that when we use virtual partitions with DLQ, at least one retry is set
              # We cannot use VP with DLQ without retries as we in order to provide ordering
              # warranties on errors with VP, we need to collapse the VPs concurrency and retry
              # without any indeterministic work
              virtual do |data, errors|
                next unless errors.empty?

                dead_letter_queue = data[:dead_letter_queue]
                virtual_partitions = data[:virtual_partitions]

                next unless dead_letter_queue[:active]
                next unless virtual_partitions[:active]
                next if dead_letter_queue[:max_retries].positive?

                [[%i[dead_letter_queue], :with_virtual_partitions]]
              end
            end
          end
        end
      end
    end
  end
end
