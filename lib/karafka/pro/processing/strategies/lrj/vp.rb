# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        module Lrj
          # Long-Running Job enabled
          # Virtual Partitions enabled
          module Vp
            # Same flow as the standard Lrj
            include Strategies::Vp::Default
            include Strategies::Lrj::Default

            # Features for this strategy
            FEATURES = %i[
              long_running_job
              virtual_partitions
            ].freeze
          end
        end
      end
    end
  end
end
