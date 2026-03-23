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
      module VirtualPartitions
        module Distributors
          # Consistent distributor that ensures messages with the same partition key
          # are always processed in the same virtual partition
          class Consistent < Base
            # Distributes messages ensuring consistent routing where messages with the same
            # partition key always go to the same virtual partition
            # @param messages [Array<Karafka::Messages::Message>]
            # @return [Hash{Integer => Array<Karafka::Messages::Message>}] hash with group ids as
            #   keys and message groups as values
            def call(messages)
              messages
                .group_by { |msg| config.reducer.call(config.partitioner.call(msg)) }
                .to_h
            end
          end
        end
      end
    end
  end
end
