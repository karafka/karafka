# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        # Filtering related init strategies
        module Lrj
          # Filtering enabled
          # LRJ enabled
          # MoM enabled
          # VPs enabled
          module FtrMomVp
            # Filtering + LRJ + Mom + VPs
            FEATURES = %i[
              filtering
              long_running_job
              manual_offset_management
              virtual_partitions
            ].freeze

            include Strategies::Lrj::MomVp
            include Strategies::Lrj::FtrMom
          end
        end
      end
    end
  end
end
