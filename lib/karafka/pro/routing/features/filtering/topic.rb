# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

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
