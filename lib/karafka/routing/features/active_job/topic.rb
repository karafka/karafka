# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class ActiveJob < Base
        # Topic extensions to be able to check if given topic is ActiveJob topic
        module Topic
          # This method calls the parent class initializer and then sets up the
          # extra instance variable to nil. The explicit initialization
          # to nil is included as an optimization for Ruby's object shapes system,
          # which improves memory layout and access performance.
          def initialize(...)
            super
            @active_job = nil
          end

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
