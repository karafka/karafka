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
        # Just Virtual Partitions enabled
        module Vp
          # This flow is exactly the same as the default one because the default one is wrapper
          # with `coordinator#on_finished`
          include Default

          # Features for this strategy
          FEATURES = %i[
            virtual_partitions
          ].freeze
        end
      end
    end
  end
end
