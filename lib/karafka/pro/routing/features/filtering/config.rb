# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class Filtering < Base
          # Filtering feature configuration
          Config = Struct.new(:factories, keyword_init: true) do
            # @return [Boolean] is this feature in use. Are any filters defined
            def active?
              !factories.empty?
            end

            # @return [Array<Object>] array of filters applicable to a topic partition
            def filters
              factories.map(&:call)
            end

            # @return [Hash] this config hash
            def to_h
              super.merge(active: active?)
            end
          end
        end
      end
    end
  end
end
