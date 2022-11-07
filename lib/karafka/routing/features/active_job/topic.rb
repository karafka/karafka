# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class ActiveJob < Base
        # Topic extensions to be able to check if given topic is ActiveJob topic
        module Topic
          # @param active [Boolean] should this topic be considered one working with ActiveJob
          #
          # @note Since this feature supports only one setting (active), we can use the old API
          # where the boolean would be an argument
          def active_job(active = false)
            @active_job ||= Config.new(active: active)
          end

          # @return [Boolean] is this an ActiveJob topic
          def active_job?
            active_job.active?
          end

          # @return [Hash] topic with all its native configuration options plus active job
          #   namespace settings
          def to_h
            super.merge(
              active_job: active_job.to_h
            ).freeze
          end
        end
      end
    end
  end
end
