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
      # Aggregator for all filters we want to have. Whether related to limiting messages based
      # on the payload or any other things.
      class Filters
        # @param filters [Array<Object>] array of filters we want to apply on the topic partition
        def initialize(filters)
          @filters = filters
        end

        # @param messages [Array<Karafka::Messages::Message>] array with messages from the
        #   partition
        def filter!(messages)
          return unless active?

          @filters.each { |filter| filter.filter!(messages) }
        end

        # @return [Boolean] did we filter out any messages during filtering run
        def filtered?
          return false unless active?

          !filtered.empty?
        end

        # @return [Boolean] did we throttle and need to backoff. If we limited our data scope
        #   in such a way, that we need to start from a certain message (first of limited), it
        #   is considered throttling.
        def throttled?
          return false unless active?

          filtered? && !cursor.nil?
        end

        # @return [Boolean] Did our throttling / potential timeout happened but also expired.
        #   It means. that from the moment we filtered to now, the potential backoff timeout has
        #   passed and no need to pause. Just potentially seeking is needed.
        def expired?
          return false unless active?

          timeout <= 0
        end

        # @return [Integer] minimum timeout we need to pause. This is the minimum for all the
        #   filters to satisfy all of them.
        def timeout
          return 0 unless active?

          filtered.map(&:timeout).min
        end

        # The first message we do need to get next time we poll. We use the minimum not to jump
        # accidentally by over any.
        def cursor
          return nil unless active?

          filtered.map(&:cursor).compact.min_by(&:offset)
        end

        private

        # @return [Boolean] is filtering active
        def active?
          !@filters.empty?
        end

        # @return [Array<Object>] filters that applied any sort of messages limiting
        def filtered
          @filters.select(&:filtered?)
        end
      end
    end
  end
end
