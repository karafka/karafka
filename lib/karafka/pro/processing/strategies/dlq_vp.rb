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
        # Dead Letter Queue enabled
        # Virtual Partitions enabled
        #
        # In general because we collapse processing in virtual partitions to one on errors, there
        # is no special action that needs to be taken because we warranty that even with VPs
        # on errors a retry collapses into a single state.
        module DlqVp
          # Features for this strategy
          FEATURES = %i[
            dead_letter_queue
            virtual_partitions
          ].freeze

          include Dlq
          include Vp
        end
      end
    end
  end
end
