# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        module Aj
          # ActiveJob enabled
          # Long-Running Job enabled
          # Manual offset management enabled
          module LrjMom
            # Same behaviour as Lrj::Mom
            include Strategies::Lrj::Mom

            # Features for this strategy
            FEATURES = %i[
              active_job
              long_running_job
              manual_offset_management
            ].freeze
          end
        end
      end
    end
  end
end
