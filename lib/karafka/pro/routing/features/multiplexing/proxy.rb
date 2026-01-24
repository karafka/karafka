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
          # Allows for multiplexing setup inside a consumer group definition
          module Proxy
            # @param min [Integer, nil] min multiplexing count or nil to set it to max, effectively
            #   disabling dynamic multiplexing
            # @param max [Integer] max multiplexing count
            # @param boot [Integer] how many listeners should we start during boot by default
            # @param scale_delay [Integer] number of ms of delay before applying any scale
            #   operation to a consumer group
            def multiplexing(min: nil, max: 1, boot: nil, scale_delay: 60_000)
              @target.current_subscription_group_details.merge!(
                multiplexing_min: min || max,
                multiplexing_max: max,
                # Picks half of max by default as long as possible. Otherwise goes with min
                multiplexing_boot: boot || [min || max, (max / 2)].max,
                multiplexing_scale_delay: scale_delay
              )
            end
          end
        end
      end
    end
  end
end
