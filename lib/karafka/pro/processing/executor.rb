# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      # Pro executor that supports periodic jobs
      class Executor < Karafka::Processing::Executor
        # Runs the code that should happen before periodic job is scheduled
        #
        # @note While jobs are called `Periodic`, from the consumer perspective it is "ticking".
        #   This name was taken for a reason: we may want to introduce periodic ticking also not
        #   only during polling but for example on wait and a name "poll" would not align well.
        #   A name "periodic" is not a verb and our other consumer actions are verbs like:
        #   consume or revoked. So for the sake of consistency we have ticking here.
        def before_schedule_periodic
          consumer.on_before_schedule_tick
        end

        # Triggers consumer ticking
        def periodic
          consumer.on_tick
        end
      end
    end
  end
end
