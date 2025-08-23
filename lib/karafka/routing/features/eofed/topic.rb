# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Eofed < Base
        # Routing topic eofed API
        module Topic
          # This method calls the parent class initializer and then sets up the
          # extra instance variable to nil. The explicit initialization
          # to nil is included as an optimization for Ruby's object shapes system,
          # which improves memory layout and access performance.
          def initialize(...)
            super
            @eofed = nil
          end

          # @param active [Boolean] should the `#eofed` job run on eof
          def eofed(active = false)
            @eofed ||= Config.new(
              active: active
            )
          end

          # @return [Boolean] Are `#eofed` jobs active
          def eofed?
            eofed.active?
          end

          # @return [Hash] topic setup hash
          def to_h
            super.merge(
              eofed: eofed.to_h
            ).freeze
          end
        end
      end
    end
  end
end
