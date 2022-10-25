# frozen_string_literal: true

module Karafka
  module Processing
    # Our processing patterns differ depending on various features configurations
    # In this namespace we collect strategies for particular feature combinations to simplify the
    # design. Based on features combinations we can then select handling strategy for a given case.
    #
    # @note The lack of common code here is intentional. It would get complex if there would be
    #   any type of composition, so each strategy is expected to be self-sufficient
    module Strategies
      # Base strategy that should be included in each strategy, just to ensure the API
      module Base
        # What should happen before jobs are enqueued
        # @note This runs from the listener thread, not recommended to put anything slow here
        def handle_before_enqueue
          raise NotImplementedError, 'Implement in a subclass'
        end

        # Post-consumption handling
        def handle_after_consume
          raise NotImplementedError, 'Implement in a subclass'
        end

        # Revocation handling
        def handle_revoked
          raise NotImplementedError, 'Implement in a subclass'
        end
      end
    end
  end
end
