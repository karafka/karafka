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
        class LongRunningJob < Base
          # Long-Running Jobs topic API extensions
          module Topic
            # @param active [Boolean] do we want to enable long-running job feature for this topic
            def long_running_job(active = false)
              @long_running_job ||= Config.new(active: active)
            end

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
