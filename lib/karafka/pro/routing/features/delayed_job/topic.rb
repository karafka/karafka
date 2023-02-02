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
        class DelayedJob < Base
          # Delayed Jobs topic API extensions
          module Topic
            # @param delay_for [Integer] time in ms for how long at least we want to lag behind
            def delayed_job(delay_for: 0)
              @delayed_job ||= Config.new(
                active: delay_for.positive?,
                delay_for: delay_for
              )
            end

            # @return [Boolean] is delayed job enabled for given topic
            def delayed_job?
              delayed_job.active?
            end

            # @return [Hash] topic with all its native configuration options plus manual offset
            #   management namespace settings
            def to_h
              super.merge(
                delayed_job: delayed_job.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
