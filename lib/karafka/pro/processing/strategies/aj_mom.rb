# frozen_string_literal: true

module Karafka
  module Pro
    module Processing
      module Strategies
        # ActiveJob enabled
        # Manual Offset management enabled
        module AjMom
          # Standard ActiveJob strategy is the same one we use for Mom
          include Mom

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
