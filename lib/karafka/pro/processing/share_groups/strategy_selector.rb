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
        # Selector of appropriate share-group processing strategy matching topic combinations.
        # When using Karafka Pro, there are extra strategies for the Pro features.
        class StrategySelector
          attr_reader :strategies

          # Features we support in the Pro offering
          SUPPORTED_FEATURES = %i[
            dead_letter_queue
          ].freeze

          # Initializes the strategy selector and preloads all strategies
          def initialize
            # We load them once for performance reasons not to do too many lookups
            @strategies = find_all
          end

          # @param topic [Karafka::Routing::ShareGroups::Topic] topic with settings based on which
          #   we find strategy
          # @return [Module] module with proper strategy
          def find(topic)
            feature_set = SUPPORTED_FEATURES.map do |feature_name|
              topic.public_send("#{feature_name}?") ? feature_name : nil
            end

            feature_set.compact!
            feature_set.sort!

            @strategies.find do |strategy|
              strategy::FEATURES.sort == feature_set
            end || raise(Errors::StrategyNotFoundError, topic.name)
          end

          private

          # @return [Array<Module>] available OSS and Pro strategies
          def find_all
            [Karafka::Processing::ShareGroups::Strategies, Strategies].flat_map do |scope|
              scope.constants.map { |k| scope.const_get(k) }
            end.uniq
          end
        end
      end
    end
  end
end
