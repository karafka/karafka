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
            # @param during_pause [Boolean] Should periodic jobs run when partition is paused. It
            #   is true by default but can be set to false if we do not want to run it when pausing
            #   occurs
            # @param during_retry [Boolean] Should we run when there was an error and we are in
            #   a retry flow. Please not that for this to work, `during_pause` also needs to be
            #   set to true as on errors retry happens after pause.
            def periodic_job(
              active = false,
              interval: nil,
              during_pause: nil,
              during_retry: nil
            )
              @periodic_job ||= begin
                # If only interval defined, it means we want to use so set to active
                active = true unless interval.nil?
                active = true unless during_pause.nil?
                active = true unless during_retry.nil?
                during_retry = false if during_retry.nil?

                # If no interval, use default
                interval ||= ::Karafka::App.config.internal.tick_interval

                Config.new(
                  active: active,
                  interval: interval,
                  during_pause: during_pause,
                  during_retry: during_retry,
                  # This is internal setting for state management, not part of the configuration
                  # Do not overwrite.
                  # If during_pause is explicit, we do not select it based on LRJ setup and we
                  # consider if fully ready out of the box
                  materialized: !during_pause.nil?
                )
              end

              return @periodic_job if @periodic_job.materialized?
              return @periodic_job unless @long_running_job

              # If not configured in any way, we want not to process during pause for LRJ.
              # LRJ pauses by default when processing and during this time we do not want to
              # tick at all. This prevents us from running periodic jobs while LRJ jobs are
              # running. This of course has a side effect of not running when paused for any
              # other reason but it is a compromise in the default settings
              @periodic_job.during_pause = !long_running_job?
              @periodic_job.materialized = true

              @periodic_job
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
