# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class ParallelSegments < Base
          # Config for parallel segments.
          # @note Used on the consumer level, not per topic
          Config = Struct.new(
            :active,
            :count,
            :partitioner,
            :reducer,
            :merge_key,
            keyword_init: true
          ) do
            alias_method :active?, :active
          end
        end
      end
    end
  end
end
