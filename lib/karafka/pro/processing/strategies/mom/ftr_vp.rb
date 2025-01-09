# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        module Mom
          # - Mom enabled
          # - Ftr enabled
          # - Vp enabled
          module FtrVp
            include Strategies::Mom::Vp
            include Strategies::Mom::Ftr

            # Features of this strategy
            FEATURES = %i[
              filtering
              manual_offset_management
              virtual_partitions
            ].freeze
          end
        end
      end
    end
  end
end
