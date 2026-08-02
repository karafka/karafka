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
        class Pausing < Base
          # Expansion allowing for a per topic pause strategy definitions
          module Topic
            # Allows for per-topic pausing strategy setting.
            #
            # Overrides the OSS `#pause` reader (this module is prepended onto `Routing::Topic`).
            # With no arguments it returns the current configuration, defaulting to the global
            # `config.pause.*` settings via `super`. With arguments it overrides the pausing
            # strategy for this topic and marks it as active.
            #
            # @param timeout [Integer] how long should we wait upon processing error (milliseconds)
            # @param max_timeout [Integer] what is the max timeout in case of an exponential
            #   backoff (milliseconds)
            # @param with_exponential_backoff [Boolean] should we use exponential backoff
            # @return [Karafka::Routing::Topic::PauseConfig] pausing config object
            def pause(timeout: nil, max_timeout: nil, with_exponential_backoff: nil)
              config = super()

              # If no arguments provided, just return the current (default or overridden) config
              return config if timeout.nil? && max_timeout.nil? && with_exponential_backoff.nil?

              config.timeout = timeout if timeout
              config.max_timeout = max_timeout if max_timeout

              unless with_exponential_backoff.nil?
                config.with_exponential_backoff = with_exponential_backoff
              end

              config.active = true

              config
            end

            # @return [Boolean] is pausing explicitly configured on a per-topic basis
            def pause?
              pause.active?
            end
          end
        end
      end
    end
  end
end
