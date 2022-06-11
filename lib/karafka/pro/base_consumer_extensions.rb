# frozen_string_literal: true

# This Karafka component is a Pro component.
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

module Karafka
  module Pro
    # Extensions to the base consumer that make it more pro and fancy
    module BaseConsumerExtensions
      # Marks this consumer revoked state as true
      # This allows us for things like lrj to finish early as this state may change during lrj
      # execution
      def on_revoked
        @revoked = true
        super
      end

      # @return [Boolean] true if partition was revoked from the current consumer
      def revoked?
        @revoked || false
      end
    end
  end
end
