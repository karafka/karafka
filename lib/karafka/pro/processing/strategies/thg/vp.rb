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
        # Throttling related init strategies
        module Thg
          # Throttling enabled
          # VPs enabled
          #
          # VPs should operate without any problems with throttling because virtual partitioning
          # happens on the limited set of messages and collective throttling applies the same
          # way as for default cases
          module Vp
            # Throttling + VPs
            FEATURES = %i[
              throttling
              virtual_partitions
            ].freeze

            include Strategies::Vp::Default
            include Strategies::Thg::Default
          end
        end
      end
    end
  end
end
