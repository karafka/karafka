# frozen_string_literal: true

module Karafka
  module Pro
    module Processing
      module Strategies
        # Manual offset management enabled
        # Virtual Partitions enabled
        module MomVp
          # Virtual Partitions work with standard Mom flow without any changes
          include Mom

          # Features for this strategy
          FEATURES = %i[
            manual_offset_management
            virtual_partitions
          ].freeze
        end
      end
    end
  end
end
