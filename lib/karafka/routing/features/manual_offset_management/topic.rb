# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class ManualOffsetManagement < Base
        # Topic extensions to be able to manage manual offset management settings
        module Topic
          # @param active [Boolean] should we stop managing the offset in Karafka and make the user
          #   responsible for marking messages as consumed.
          # @return [Config] defined config
          #
          # @note Since this feature supports only one setting (active), we can use the old API
          # where the boolean would be an argument
          def manual_offset_management(active = false)
            @manual_offset_management ||= Config.new(active: active)
          end

          # @return [Boolean] is manual offset management enabled for a given topic
          def manual_offset_management?
            manual_offset_management.active?
          end

          # @return [Hash] topic with all its native configuration options plus manual offset
          #   management namespace settings
          def to_h
            super.merge(
              manual_offset_management: manual_offset_management.to_h
            ).freeze
          end
        end
      end
    end
  end
end
