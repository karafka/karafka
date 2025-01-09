# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class Filtering < Base
          # Filtering feature topic extensions
          module Topic
            # @param factory [#call, nil] Callable that can produce new filters instances per
            #   assigned topic partition. nil as default so this feature is disabled
            def filter(factory = nil)
              @filtering ||= Config.new(factories: [])
              @filtering.factories << factory if factory
              @filtering
            end

            # @param args [Array] Anything `#filter` accepts
            # @return [Filtering::Config] alias to match the naming API for features
            def filtering(*args)
              filter(*args)
            end

            # @return [Boolean] is a given job throttled
            def filtering?
              filtering.active?
            end

            # @return [Hash] topic with all its native configuration options plus throttling
            def to_h
              super.merge(
                filtering: filtering.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
