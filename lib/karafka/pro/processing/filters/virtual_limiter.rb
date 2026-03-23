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
    module Processing
      module Filters
        # Removes messages that are already marked as consumed in the virtual offset manager
        # This should operate only when using virtual partitions.
        #
        # This cleaner prevents us from duplicated processing of messages that were virtually
        # marked as consumed even if we could not mark them as consumed in Kafka. This allows us
        # to limit reprocessing when errors occur drastically when operating with virtual
        # partitions
        #
        # @note It should be registered only when VPs are used
        class VirtualLimiter < Base
          # @param manager [Processing::VirtualOffsetManager]
          # @param collapser [Processing::Collapser]
          def initialize(manager, collapser)
            @manager = manager
            @collapser = collapser

            super()
          end

          # Remove messages that we already marked as virtually consumed. Does nothing if not in
          # the collapsed mode.
          #
          # @param messages [Array<Karafka::Messages::Message>]
          def apply!(messages)
            return unless @collapser.collapsed?

            marked = @manager.marked

            messages.delete_if { |message| marked.include?(message.offset) }
          end

          # @return [nil] This filter does not deal with pausing, so timeout is always nil
          def timeout
            nil
          end
        end
      end
    end
  end
end
