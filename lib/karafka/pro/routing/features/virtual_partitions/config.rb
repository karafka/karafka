# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class VirtualPartitions < Base
          # Config for virtual partitions
          Config = Struct.new(
            :active,
            :partitioner,
            :max_partitions,
            :offset_metadata_strategy,
            :reducer,
            keyword_init: true
          ) { alias_method :active?, :active }
        end
      end
    end
  end
end
