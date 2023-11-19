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
        # Namespace for ActiveJob related strategies
        module Aj
          # ActiveJob enabled
          # Filtering enabled
          # Manual Offset management enabled
          # Virtual partitions enabled
          module FtrMomVp
            include Strategies::Aj::FtrMom
            include Strategies::Aj::MomVp

            # Features for this strategy
            FEATURES = %i[
              active_job
              filtering
              manual_offset_management
              virtual_partitions
            ].freeze

            # AJ with VPs always has intermediate marking disabled, hence we need to do it post
            # execution always.
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  return if revoked?

                  mark_as_consumed(last_group_message)

                  handle_post_filtering
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
