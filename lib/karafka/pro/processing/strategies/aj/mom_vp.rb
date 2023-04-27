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
    module Processing
      module Strategies
        module Aj
          # ActiveJob enabled
          # Manual offset management enabled
          # Virtual Partitions enabled
          module MomVp
            include Strategies::Default
            include Strategies::Vp::Default

            # Features for this strategy
            FEATURES = %i[
              active_job
              manual_offset_management
              virtual_partitions
            ].freeze

            # Standard flow without any features
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  return if revoked?

                  mark_as_consumed(last_group_message)
                else
                  retry_after_pause
                end
              end
            end
          end
        end
      end
    end
  end
end
