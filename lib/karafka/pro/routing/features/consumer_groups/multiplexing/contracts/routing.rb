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
        module ConsumerGroups
          class Multiplexing < Base
            module Contracts
              # Contract that validates that dynamic multiplexing is not used with statistics
              # disabled. Dynamic multiplexing relies on statistics emitted events for scaling
              # decisions and will not function properly without them.
              class Routing < Karafka::Contracts::Base
                configure do |config|
                  config.error_messages = YAML.safe_load_file(
                    File.join(Karafka.gem_root, "config", "locales", "pro_errors.yml")
                  ).fetch("en").fetch("validations").fetch("routing")
                end

                # @param _builder [Karafka::Routing::Builder]
                # @param scope [Array<String>]
                def validate!(_builder, scope: [])
                  has_dynamic = Karafka::App
                    .subscription_groups
                    .values
                    .flat_map(&:itself)
                    .any? { |sg| sg.multiplexing? && sg.multiplexing.dynamic? }

                  return unless has_dynamic

                  stats_interval = App.config.kafka[:"statistics.interval.ms"]

                  return unless stats_interval
                  return unless stats_interval.zero?

                  super(
                    { dynamic_multiplexing_with_statistics_disabled: true },
                    scope: scope
                  )
                end

                virtual do |data, errors|
                  next unless errors.empty?
                  next unless data[:dynamic_multiplexing_with_statistics_disabled]

                  [[%i[multiplexing], :statistics_required_for_dynamic_multiplexing]]
                end
              end
            end
          end
        end
      end
    end
  end
end
