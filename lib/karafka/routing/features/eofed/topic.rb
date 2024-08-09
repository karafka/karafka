# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Eofed < Base
        # Routing topic eofed API
        module Topic
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
