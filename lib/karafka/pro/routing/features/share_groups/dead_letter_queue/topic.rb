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
            # DLQ topic extensions
            module Topic
              # After how many retries should data be moved to DLQ
              DEFAULT_MAX_RETRIES = 3

              private_constant :DEFAULT_MAX_RETRIES

              # This method sets up the extra instance variable to nil before calling
              # the parent class initializer. The explicit initialization
              # to nil is included as an optimization for Ruby's object shapes system,
              # which improves memory layout and access performance.
              def initialize(...)
                @dead_letter_queue = nil
                super
              end

              # @param max_retries [Integer] after how many retries (redeliveries) should we move a
              #   failing record to the dlq. It needs to be lower than the share group
              #   `share.delivery.count.limit` (5 by default), as the broker drops records that
              #   reach that limit.
              # @param topic [String, false] where the records should be moved if failing or false
              #   if we do not want to move them anywhere and just reject them
              # @param dispatch_method [Symbol] `:produce_async` or `:produce_sync`. Describes
              #   whether dispatch on dlq should be sync or async (async by default)
              # @return [Config] defined config
              def dead_letter_queue(
                max_retries: DEFAULT_MAX_RETRIES,
                topic: nil,
                dispatch_method: :produce_async
              )
                @dead_letter_queue ||= Config.new(
                  active: !topic.nil?,
                  max_retries: max_retries,
                  topic: topic,
                  dispatch_method: dispatch_method
                )
              end

              # @return [Boolean] is the dlq active or not
              def dead_letter_queue?
                dead_letter_queue.active?
              end

              # @return [Hash] topic with all its native configuration options plus dlq settings
              def to_h
                super.merge(
                  dead_letter_queue: dead_letter_queue.to_h
                ).freeze
              end
            end
          end
        end
      end
    end
  end
end
