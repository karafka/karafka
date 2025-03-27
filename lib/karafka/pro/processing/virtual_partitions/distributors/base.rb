# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      # Processing components for virtual partitions
      module VirtualPartitions
        # Distributors for virtual partitions
        module Distributors
          # Base class for all virtual partition distributors
          class Base
            # @param config [Karafka::Pro::Routing::Features::VirtualPartitions::Config]
            def initialize(config)
              @config = config
            end

            private

            # @return [Karafka::Pro::Routing::Features::VirtualPartitions::Config]
            attr_reader :config
          end
        end
      end
    end
  end
end
