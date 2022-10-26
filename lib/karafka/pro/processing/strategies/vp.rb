# frozen_string_literal: true

module Karafka
  module Pro
    module Processing
      module Strategies
        # Just Virtual Partitions enabled
        module Vp
          # This flow is exactly the same as the default one because the default one is wrapper
          # with `coordinator#on_finished`
          include Default

          # Features for this strategy
          FEATURES = %i[
            virtual_partitions
          ].freeze
        end
      end
    end
  end
end
