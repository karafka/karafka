# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module ParallelSegments
        module Filters
          # Filter used for handling parallel segments when manual offset management (mom) is
          # enabled. Provides message distribution without any post-filtering offset state
          # management as it is fully user-based.
          #
          # Since with manual offset management we need to ensure that offsets are never marked
          # even in cases where all data in a batch is filtered out.
          #
          # This separation allows for cleaner implementation and easier debugging of each flow.
          #
          # @note This filter should be used only when manual offset management is enabled.
          #   For automatic offset management scenarios use the regular filter instead.
          class Mom < Base
          end
        end
      end
    end
  end
end
