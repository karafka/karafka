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
        # Defines all the before schedule handlers for appropriate actions
        %i[
          consume
          idle
          revoked
          shutdown
        ].each do |action|
          class_eval <<~RUBY, __FILE__, __LINE__ + 1
            def handle_before_schedule_#{action}
              # What should happen before scheduling this work
              raise NotImplementedError, 'Implement in a subclass'
            end
          RUBY
        end

        # What should happen before we kick in the processing
        def handle_before_consume
          raise NotImplementedError, 'Implement in a subclass'
        end

        # What should happen in the processing
        def handle_consume
          raise NotImplementedError, 'Implement in a subclass'
        end

        # Post-consumption handling
        def handle_after_consume
          raise NotImplementedError, 'Implement in a subclass'
        end

        # Idle run handling
        def handle_idle
          raise NotImplementedError, 'Implement in a subclass'
        end

        # Revocation handling
        def handle_revoked
          raise NotImplementedError, 'Implement in a subclass'
        end

        # Shutdown handling
        def handle_shutdown
          raise NotImplementedError, 'Implement in a subclass'
        end
      end
    end
  end
end
