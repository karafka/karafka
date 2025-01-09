# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      # Namespace for periodic jobs related processing APIs
      module PeriodicJob
        # Consumer extra methods useful only when periodic jobs are in use
        module Consumer
          class << self
            # Defines an empty `#tick` method if not present
            #
            # We define it that way due to our injection strategy flow.
            #
            # @param consumer_singleton_class [Karafka::BaseConsumer] consumer singleton class
            #   that is being enriched with periodic jobs API
            def included(consumer_singleton_class)
              # Do not define empty tick method on consumer if it already exists
              # We only define it when it does not exist to have empty periodic ticking
              #
              # We need to check both cases (public and private) since user is not expected to
              # have this method public
              return if consumer_singleton_class.instance_methods.include?(:tick)
              return if consumer_singleton_class.private_instance_methods.include?(:tick)

              # Create empty ticking method
              consumer_singleton_class.class_eval do
                def tick; end
              end
            end
          end

          # Runs the on-schedule tick periodic operations
          # This method is an alias but is part of the naming convention used for other flows, this
          # is why we do not reference the `handle_before_schedule_tick` directly
          def on_before_schedule_tick
            handle_before_schedule_tick
          end

          # Used by the executor to trigger consumer tick
          # @private
          def on_tick
            handle_tick
          rescue StandardError => e
            Karafka.monitor.instrument(
              'error.occurred',
              error: e,
              caller: self,
              type: 'consumer.tick.error'
            )
          end
        end
      end
    end
  end
end
