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
          # Adds methods needed for the multiplexing to work
          module SubscriptionGroup
            # @return [Config] multiplexing config
            def multiplexing
              @multiplexing ||= begin
                max = @details.fetch(:multiplexing_max, 1)
                min = @details.fetch(:multiplexing_min, max)
                boot = @details.fetch(:multiplexing_boot, max / 2)
                scale_delay = @details.fetch(:multiplexing_scale_delay, 60_000)
                active = max > 1

                Config.new(
                  active: active,
                  min: min,
                  max: max,
                  boot: boot,
                  scale_delay: scale_delay
                )
              end
            end

            # @return [Boolean] is multiplexing active
            def multiplexing?
              multiplexing.active?
            end
          end
        end
      end
    end
  end
end
