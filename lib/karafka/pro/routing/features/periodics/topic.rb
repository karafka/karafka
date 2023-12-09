# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

module Karafka
  module Pro
    module Routing
      module Features
        class Periodics < Base
          # Periodic topic action flows extensions
          module Topic
            def periodic(active = false)
              @periodics ||= Config.new(active: active)
            end

            def periodics
              periodic
            end

            def periodics?
              periodics.active?
            end

            # @return [Hash] topic with all its native configuration options plus periodics flows
            #   settings
            def to_h
              super.merge(
                periodics: periodics.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
