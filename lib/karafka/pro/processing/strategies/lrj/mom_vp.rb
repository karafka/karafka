# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        # Namespace for all the LRJ starting strategies
        module Lrj
          # Long-Running Job enabled
          # Manual offset management enabled
          # Virtual Partitions enabled
          module MomVp
            include Strategies::Mom::Vp
            include Strategies::Lrj::Mom

            # Features for this strategy
            FEATURES = %i[
              long_running_job
              manual_offset_management
              virtual_partitions
            ].freeze
          end
        end
      end
    end
  end
end
