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
          # Filtering enabled
          # Manual Offset management enabled
          module FtrMom
            # Same as standard Mom::Ftr
            include Strategies::Mom::Ftr

            # Features for this strategy
            FEATURES = %i[
              active_job
              filtering
              manual_offset_management
            ].freeze
          end
        end
      end
    end
  end
end
