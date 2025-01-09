# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class LongRunningJob < Base
          # Long-Running Jobs topic API extensions
          module Topic
            # @param active [Boolean] do we want to enable long-running job feature for this topic
            def long_running_job(active = false)
              @long_running_job ||= Config.new(active: active)
            end

            alias long_running long_running_job

            # @return [Boolean] is a given job on a topic a long-running one
            def long_running_job?
              long_running_job.active?
            end

            # @return [Hash] topic with all its native configuration options plus lrj
            def to_h
              super.merge(
                long_running_job: long_running_job.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
