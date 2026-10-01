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
    module Processing
      module ShareGroups
        # Processing components for share-group virtual partitions
        module VirtualPartitions
          # Distributors for share-group virtual partitions
          module Distributors
            # Spreads records evenly across the virtual partitions, one by one. Share groups do not
            # need to preserve any ordering, so this gives the most even split of the work.
            class RoundRobin < Processing::ConsumerGroups::VirtualPartitions::Distributors::Base
              # @param messages [Array<Karafka::Messages::Message>] records of a topic partition
              # @return [Hash{Integer => Array<Karafka::Messages::Message>}] records per virtual
              #   partition
              def call(messages)
                groups = Hash.new { |hash, key| hash[key] = [] }

                messages.each_with_index do |message, index|
                  groups[index % config.max_partitions] << message
                end

                groups
              end
            end
          end
        end
      end
    end
  end
end
