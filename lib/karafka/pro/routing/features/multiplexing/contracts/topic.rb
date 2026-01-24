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
        class Multiplexing < Base
          # Namespace for multiplexing feature contracts
          module Contracts
            # Validates the subscription group multiplexing setup
            # We validate it on the topic level as subscription groups are not built during the
            # routing as they are pre-run dynamically built.
            #
            # multiplexing attributes are optional since multiplexing may not be enabled
            class Topic < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load_file(
                  File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                ).fetch('en').fetch('validations').fetch('routing').fetch('topic')
              end

              nested(:subscription_group_details) do
                optional(:multiplexing_min) { |val| val.is_a?(Integer) && val >= 1 }
                optional(:multiplexing_max) { |val| val.is_a?(Integer) && val >= 1 }
                optional(:multiplexing_boot) { |val| val.is_a?(Integer) && val >= 1 }
                optional(:multiplexing_scale_delay) { |val| val.is_a?(Integer) && val >= 1_000 }
              end

              # Makes sure min is not more than max
              virtual do |data, errors|
                next unless errors.empty?
                next unless min(data)
                next unless max(data)

                min = min(data)
                max = max(data)

                next if min <= max

                [[%w[subscription_group_details], :multiplexing_min_max_mismatch]]
              end

              # Makes sure, that boot is between min and max
              virtual do |data, errors|
                next unless errors.empty?
                next unless min(data)
                next unless max(data)
                next unless boot(data)

                min = min(data)
                max = max(data)
                boot = boot(data)

                next if boot.between?(min, max)

                [[%w[subscription_group_details], :multiplexing_boot_mismatch]]
              end

              # Makes sure, that boot is equal to min and max when not in dynamic mode
              virtual do |data, errors|
                next unless errors.empty?
                next unless min(data)
                next unless max(data)
                next unless boot(data)

                min = min(data)
                max = max(data)
                boot = boot(data)

                # In dynamic mode there are other rules to check boot
                next if min != max
                next if boot == min

                [[%w[subscription_group_details], :multiplexing_boot_not_dynamic]]
              end

              # Makes sure we do not run multiplexing with 1 always which does not make much sense
              # because then it behaves like without multiplexing and can create problems for
              # users running multiplexed subscription groups with multiple topics
              virtual do |data, errors|
                next unless errors.empty?
                next unless min(data)
                next unless max(data)

                min = min(data)
                max = max(data)

                next unless min == 1 && max == 1

                [[%w[subscription_group_details], :multiplexing_one_not_enough]]
              end

              class << self
                # @param data [Hash] topic details
                # @return [Integer, false] min or false if missing
                def min(data)
                  data[:subscription_group_details].fetch(:multiplexing_min, false)
                end

                # @param data [Hash] topic details
                # @return [Integer, false] max or false if missing
                def max(data)
                  data[:subscription_group_details].fetch(:multiplexing_max, false)
                end

                # @param data [Hash] topic details
                # @return [Integer, false] boot or false if missing
                def boot(data)
                  data[:subscription_group_details].fetch(:multiplexing_boot, false)
                end
              end
            end
          end
        end
      end
    end
  end
end
