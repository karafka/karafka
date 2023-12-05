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

          # Runs the consumption jobs scheduling flow under a mutex
          #
          # @param jobs_array [Array<Karafka::Processing::Jobs::Base>] jobs for scheduling
          def on_schedule_consumption(jobs_array)
            @mutex.synchronize do
              schedule_consumption(jobs_array)
            end
          end

          # Should schedule the consumption jobs
          #
          # @param _jobs_array [Array<Karafka::Processing::Jobs::Base>] jobs for scheduling
          def schedule_consumption(_jobs_array)
            raise NotImplementedError, 'Implement in a subclass'
          end

          # Runs the revocation jobs scheduling flow under a mutex
          #
          # @param jobs_array [Array<Karafka::Processing::Jobs::Base>] jobs for scheduling
          def on_schedule_revocation(jobs_array)
            @mutex.synchronize do
              schedule_revocation(jobs_array)
            end
          end

          # Schedules the revocation jobs.
          #
          # @param jobs_array [Array<Karafka::Processing::Jobs::Base>] jobs for scheduling
          #
          # @note We provide a default scheduler logic here because by default revocation jobs
          #   should be scheduled as fast as possible.
          def schedule_revocation(jobs_array)
            jobs_array.each do |job|
              @queue << job
            end
          end

          # Runs the shutdown jobs scheduling flow under a mutex
          #
          # @param jobs_array [Array<Karafka::Processing::Jobs::Base>] jobs for scheduling
          def on_schedule_shutdown(jobs_array)
            @mutex.synchronize do
              schedule_shutdown(jobs_array)
            end
          end

          # Schedules the shutdown jobs.
          #
          # @param jobs_array [Array<Karafka::Processing::Jobs::Base>] jobs for scheduling
          #
          # @note We provide a default scheduler logic here because by default revocation jobs
          #   should be scheduled as fast as possible.
          def schedule_shutdown(jobs_array)
            jobs_array.each do |job|
              @queue << job
            end
          end

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
        end
      end
    end
  end
end
