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
