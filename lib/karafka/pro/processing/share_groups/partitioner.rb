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

module Karafka
  module Pro
    module Processing
      # Pro share-group processing components
      module ShareGroups
        # Pro share-group partitioner that can split the records of a topic partition from a poll
        # batch into virtual partitions. Mirrors {Pro::Processing::ConsumerGroups::Partitioner},
        # without the collapsing (share groups have no ordering to restore after errors).
        class Partitioner < Karafka::Processing::ShareGroups::Partitioner
          # @param topic [String] topic name
          # @param messages [Array<Karafka::Messages::Message>] karafka messages of one partition
          # @param _coordinator [Karafka::Processing::ShareGroups::Coordinator] processing
          #   coordinator that will be used with those messages
          # @yieldparam [Integer] group id
          # @yieldparam [Array<Karafka::Messages::Message>] karafka messages
          def call(topic, messages, _coordinator)
            ktopic = @subscription_group.topics.find(topic)
            vps = ktopic.virtual_partitions

            # We only partition work if we have a virtual partitioner and more than one thread
            # to process the data
            if vps.active? && vps.max_partitions > 1
              begin
                groupings = vps.distributor.call(messages)
              rescue => e
                # This should not happen. If you are seeing this it means your partitioner code
                # failed and raised an error. We highly recommend mitigating partitioner level
                # errors on the user side because this type of collapse should be considered a
                # last resort
                Karafka.monitor.instrument(
                  "error.occurred",
                  caller: self,
                  error: e,
                  messages: messages,
                  type: "virtual_partitions.partitioner.error"
                )

                groupings = { 0 => messages }
              end

              groupings.each do |key, messages_group|
                yield(key, messages_group)
              end
            else
              # When no virtual partitioner, works as regular one
              yield(0, messages)
            end
          end
        end
      end
    end
  end
end
