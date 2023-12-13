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
        class PeriodicJob < Base
          # Periodic topic action flows extensions
          module Topic
            # Defines topic as periodic. Periodic topics consumers will invoke `#tick` with each
            # poll where messages were not received.
            # @param active [Boolean] should ticking happen for this topic assignments.
            # @param interval [Integer] minimum interval to run periodic jobs on given topic.
            def periodic_job(active = false, interval: nil)
              @periodic_job ||= begin
                # If only interval defined, it means we want to use so set to active
                active = true if interval.is_a?(Integer)
                # If no interval, use default
                interval ||= ::Karafka::App.config.internal.tick_interval

                Config.new(active: active, interval: interval)
              end
            end

            alias periodic periodic_job

            # @return [Boolean] is periodics active
            def periodic_job?
              periodic_job.active?
            end

            # @return [Hash] topic with all its native configuration options plus periodics flows
            #   settings
            def to_h
              super.merge(
                periodic_job: periodic_job.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
