# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        # Namespace for ActiveJob related strategies
        module Aj
          # ActiveJob enabled
          # Manual Offset management enabled
          module Mom
            # Standard ActiveJob strategy is the same one we use for Mom
            include Strategies::Mom::Default

            # Features for this strategy
            FEATURES = %i[
              active_job
              manual_offset_management
            ].freeze
          end
        end
      end
    end
  end
end
