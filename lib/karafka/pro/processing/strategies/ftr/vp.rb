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
        # Filtering related init strategies
        module Ftr
          # Filtering enabled
          # VPs enabled
          #
          # VPs should operate without any problems with filtering because virtual partitioning
          # happens on the limited set of messages and collective filtering applies the same
          # way as for default cases
          module Vp
            # Filtering + VPs
            FEATURES = %i[
              filtering
              virtual_partitions
            ].freeze

            include Strategies::Vp::Default
            include Strategies::Ftr::Default
          end
        end
      end
    end
  end
end
