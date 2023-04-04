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
    module Processing
      # Aggregator for any filters we want to have. Whether related to limiting messages based
      # on the payload or any other things.
      class Filters
        def initialize
          @filters = []
          @results = []
        end

        def <<(filter)
          @filters << filter
        end

        def filter!(messages)
          return if @filters.empty?

          @filters.each { |filter| filter.filter!(messages) }
        end

        def filtered?
          !filtered.empty?
        end

        def throttled?
          filtered? && !message.nil?
        end

        def expired?
          filtered? && timeout <= 0
        end

        def timeout
          filtered.map(&:timeout).min
        end

        def message
          filtered.map(&:message).compact.min_by(&:offset)
        end

        private

        def filtered
          @filters.select(&:filtered?)
        end
      end
    end
  end
end
