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
    module Processing
      # Namespace for Pro schedulers related components
      module Schedulers
        # Base for all the Pro custom schedulers
        #
        # It wraps the Scheduler API with mutex to ensure, that during scheduling we do not start
        # scheduling other work that could impact the decision making in between multiple
        # subscription groups running in separate threads.
        #
        # @note All the `on_` methods can be redefined with a non-thread-safe versions without
        #   locks if needed, however when doing so, ensure that your scheduler is stateless.
        class Base
          # @param queue [Karafka::Processing::JobsQueue] queue where we want to put the jobs
          def initialize(queue)
            @queue = queue
            @mutex = Mutex.new
          end

          # Schedules any jobs provided in a fifo order
          # @param jobs_array [Array<Karafka::Processing::Jobs::Base>]
          def schedule_fifo(jobs_array)
            jobs_array.each do |job|
              @queue << job
            end
          end

          # Runs the consumption jobs scheduling flow under a mutex
          #
          # @param jobs_array
          #   [Array<Karafka::Processing::Jobs::Consume, Processing::Jobs::ConsumeNonBlocking>]
          #   jobs for scheduling
          def on_schedule_consumption(jobs_array)
            @mutex.synchronize do
              schedule_consumption(jobs_array)
            end
          end

          # Should schedule the consumption jobs
          #
          # @param _jobs_array
          #   [Array<Karafka::Processing::Jobs::Consume, Processing::Jobs::ConsumeNonBlocking>]
          #   jobs for scheduling
          def schedule_consumption(_jobs_array)
            raise NotImplementedError, "Implement in a subclass"
          end

          # Runs the revocation jobs scheduling flow under a mutex
          #
          # @param jobs_array
          #   [Array<Karafka::Processing::Jobs::Revoked, Processing::Jobs::RevokedNonBlocking>]
          #   jobs for scheduling
          def on_schedule_revocation(jobs_array)
            @mutex.synchronize do
              schedule_revocation(jobs_array)
            end
          end

          # Runs the shutdown jobs scheduling flow under a mutex
          #
          # @param jobs_array [Array<Karafka::Processing::Jobs::Shutdown>] jobs for scheduling
          def on_schedule_shutdown(jobs_array)
            @mutex.synchronize do
              schedule_shutdown(jobs_array)
            end
          end

          # Runs the idle jobs scheduling flow under a mutex
          #
          # @param jobs_array [Array<Karafka::Processing::Jobs::Idle>] jobs for scheduling
          def on_schedule_idle(jobs_array)
            @mutex.synchronize do
              schedule_idle(jobs_array)
            end
          end

          # Runs the periodic jobs scheduling flow under a mutex
          #
          # @param jobs_array
          #   [Array<Processing::Jobs::Periodic, Processing::Jobs::PeriodicNonBlocking>]
          #   jobs for scheduling
          def on_schedule_periodic(jobs_array)
            @mutex.synchronize do
              schedule_periodic(jobs_array)
            end
          end

          # Schedule by default all except consumption as fifo
          alias_method :schedule_revocation, :schedule_fifo
          alias_method :schedule_shutdown, :schedule_fifo
          alias_method :schedule_idle, :schedule_fifo
          alias_method :schedule_periodic, :schedule_fifo

          # Runs the manage tick under mutex
          def on_manage
            @mutex.synchronize { manage }
          end

          # Should manage scheduling on jobs state changes
          #
          # By default does nothing as default schedulers are stateless
          def manage
            nil
          end

          # Runs clearing under mutex
          #
          # @param group_id [String] Subscription group id
          def on_clear(group_id)
            @mutex.synchronize { clear(group_id) }
          end

          # By default schedulers are stateless, so nothing to clear.
          #
          # @param _group_id [String] Subscription group id
          def clear(_group_id)
            nil
          end

          private

          # @return [Karafka::Processing::JobsQueue] jobs queue reference for internal usage
          #   inside of the scheduler
          attr_reader :queue
        end
      end
    end
  end
end
