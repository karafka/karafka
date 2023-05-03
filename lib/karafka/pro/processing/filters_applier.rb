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
      # Applier for all filters we want to have. Whether related to limiting messages based
      # on the payload or any other things.
      #
      # From the outside world perspective, this encapsulates all the filters.
      # This means that this is the API we expose as a single filter, allowing us to control
      # the filtering via many filters easily.
      class FiltersApplier
        # @return [Array] registered filters array. Useful if we want to inject internal context
        #   aware filters.
        attr_reader :filters

        # @param coordinator [Pro::Coordinator] pro coordinator
        def initialize(coordinator)
          # Builds filters out of their factories
          # We build it that way (providing topic and partition) because there may be a case where
          # someone wants to have a specific logic that is per topic or partition. Like for example
          # a case where there is a cache bypassing revocations for topic partition.
          #
          # We provide full Karafka routing topic here and not the name only, in case the filter
          # would be customized based on other topic settings (like VPs, etc)
          #
          # This setup allows for biggest flexibility also because topic object holds the reference
          # to the subscription group and consumer group
          @filters = coordinator.topic.filtering.factories.map do |factory|
            factory.call(coordinator.topic, coordinator.partition)
          end
        end

        # @param messages [Array<Karafka::Messages::Message>] array with messages from the
        #   partition
        def apply!(messages)
          return unless active?

          @filters.each { |filter| filter.apply!(messages) }
        end

        # @return [Boolean] did we filter out any messages during filtering run
        def applied?
          return false unless active?

          !applied.empty?
        end

        # @return [Symbol] consumer post-filtering action that should be taken
        def action
          return :skip unless applied?

          # The highest priority is on a potential backoff from any of the filters because it is
          # the less risky (delay and continue later)
          return :pause if applied.any? { |filter| filter.action == :pause }

          # If none of the filters wanted to pause, we can check for any that would want to seek
          # and if there is any, we can go with this strategy
          return :seek if applied.any? { |filter| filter.action == :seek }

          :skip
        end

        # @return [Integer] minimum timeout we need to pause. This is the minimum for all the
        #   filters to satisfy all of them.
        def timeout
          applied.map(&:timeout).compact.min || 0
        end

        # The first message we do need to get next time we poll. We use the minimum not to jump
        # accidentally by over any.
        # @return [Karafka::Messages::Message, nil] cursor message or nil if none
        def cursor
          return nil unless active?

          applied.map(&:cursor).compact.min_by(&:offset)
        end

        private

        # @return [Boolean] is filtering active
        def active?
          !@filters.empty?
        end

        # @return [Array<Object>] filters that applied any sort of messages limiting
        def applied
          @filters.select(&:applied?)
        end
      end
    end
  end
end
