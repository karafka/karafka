# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

module Karafka
  module Pro
    module Routing
      module Features
        class PeriodicJob < Base
          # Periodic topic action flows extensions
          module Topic
            # This method calls the parent class initializer and then sets up the
            # extra instance variable to nil. The explicit initialization
            # to nil is included as an optimization for Ruby's object shapes system,
            # which improves memory layout and access performance.
            def initialize(...)
              super
              @periodic_job = nil
            end

            # Defines topic as periodic. Periodic topics consumers will invoke `#tick` with each
            # poll where messages were not received.
            # @param active [Boolean] should ticking happen for this topic assignments.
            # @param interval [Integer] minimum interval to run periodic jobs on given topic.
            # @param during_pause [Boolean, nil] Should periodic jobs run when partition is paused.
            #   It is set to `nil` by default allowing for detection when this value is not
            #   configured but should be built dynamically based on LRJ status.
            # @param during_retry [Boolean, nil] Should we run when there was an error and we are
            #   in a retry flow. Please note that for this to work, `during_pause` also needs to be
            #   set to true as errors retry happens after pause.
            def periodic_job(
              active = false,
              interval: nil,
              during_pause: nil,
              during_retry: nil
            )
              @periodic_job ||= begin
                # Set to active if any of the values was configured
                active = true unless interval.nil?
                active = true unless during_pause.nil?
                active = true unless during_retry.nil?
                # Default is not to retry during retry flow
                during_retry = false if during_retry.nil?

                # If no interval, use default
                interval ||= Karafka::App.config.internal.tick_interval

                Config.new(
                  active: active,
                  interval: interval,
                  during_pause: during_pause,
                  during_retry: during_retry,
                  # This is internal setting for state management, not part of the configuration
                  # Do not overwrite.
                  # If `during_pause` is explicit, we do not select it based on LRJ setup and we
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

            alias_method :periodic, :periodic_job

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
