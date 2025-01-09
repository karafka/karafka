# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
