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
        class VirtualPartitions < Base
          # Configuration for virtual partitions feature
          Config = Struct.new(
            :active,
            :partitioner,
            :max_partitions,
            :offset_metadata_strategy,
            :reducer,
            :distribution,
            keyword_init: true
          ) do
            # @return [Boolean] is this feature active
            def active?
              active
            end

            # @return [Object] distributor instance for the current distribution
            def distributor
              @distributor ||= case distribution
              when :balanced
                Processing::VirtualPartitions::Distributors::Balanced.new(self)
              when :consistent
                Processing::VirtualPartitions::Distributors::Consistent.new(self)
              else
                raise Karafka::Errors::UnsupportedCaseError, distribution
              end
            end
          end
        end
      end
    end
  end
end
