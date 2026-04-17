# frozen_string_literal: true

module Karafka
  module Processing
    # Consumer-group-specific processing components (driven by rebalance callbacks and partition
    # ticks). Parallel `ShareGroups` will live next to this namespace once KIP-932 lands.
    module ConsumerGroups
      module Strategies
        # ActiveJob enabled
        # Manual offset management enabled
        #
        # This is the default AJ strategy since AJ cannot be used without MOM
        module AjMom
          include Mom

          # Apply strategy when only when using AJ with MOM
          FEATURES = %i[
            active_job
            manual_offset_management
          ].freeze
        end
      end
    end
  end
end
