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
        class AdaptiveIterator < Base
          # Namespace for adaptive iterator contracts
          module Contracts
            # Contract to validate configuration of the adaptive iterator feature
            class Topic < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load_file(
                  File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                ).fetch('en').fetch('validations').fetch('routing').fetch('topic')
              end

              nested(:adaptive_iterator) do
                required(:active) { |val| [true, false].include?(val) }
                required(:safety_margin) { |val| val.is_a?(Integer) && val.positive? && val < 100 }
                required(:clean_after_yielding) { |val| [true, false].include?(val) }

                required(:marking_method) do |val|
                  %i[mark_as_consumed mark_as_consumed!].include?(val)
                end
              end

              # Since adaptive iterator uses `#seek` and can break processing in the middle, we
              # cannot use it with virtual partitions that can process data in a distributed
              # manner
              virtual do |data, errors|
                next unless errors.empty?

                adaptive_iterator = data[:adaptive_iterator]
                virtual_partitions = data[:virtual_partitions]

                next unless adaptive_iterator[:active]
                next unless virtual_partitions[:active]

                [[%i[adaptive_iterator], :with_virtual_partitions]]
              end

              # There is no point of using the adaptive iterator with LRJ because of how LRJ works
              virtual do |data, errors|
                next unless errors.empty?

                adaptive_iterator = data[:adaptive_iterator]
                long_running_jobs = data[:long_running_job]

                next unless adaptive_iterator[:active]
                next unless long_running_jobs[:active]

                [[%i[adaptive_iterator], :with_long_running_job]]
              end
            end
          end
        end
      end
    end
  end
end
