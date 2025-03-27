# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
