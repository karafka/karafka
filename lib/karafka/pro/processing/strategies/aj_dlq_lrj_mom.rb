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
      module Strategies
        # ActiveJob enabled
        # DLQ enabled
        # Long-Running Job enabled
        # Manual offset management enabled
        #
        # This case is a bit of special. Please see the `AjDlqMom` for explanation on how the
        # offset management works in this case.
        module AjDlqLrjMom
          include AjLrjMom
          include AjDlqMom

          # Features for this strategy
          FEATURES = %i[
            active_job
            long_running_job
            manual_offset_management
            dead_letter_queue
          ].freeze
        end
      end
    end
  end
end
