# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        # Virtual Partitions feature config and DSL namespace.
        #
        # Virtual Partitions allow you to parallelize the processing of data from a single
        # partition. This can drastically increase throughput when IO operations are involved.
        class VirtualPartitions < Base
        end
      end
    end
  end
end
