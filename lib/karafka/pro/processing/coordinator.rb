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
      # Pro coordinator that provides extra orchestration methods useful for parallel processing
      # within the same partition
      class Coordinator < ::Karafka::Processing::Coordinator
        # @param args [Object] anything the base coordinator accepts
        def initialize(*args)
          super
          @on_enqueued_invoked = false
          @on_started_invoked = false
          @on_finished_invoked = false
          @flow_lock = Mutex.new
        end

        # Starts the coordination process
        # @param messages [Array<Karafka::Messages::Message>] messages for which processing we are
        #   going to coordinate.
        def start(messages)
          super

          @mutex.synchronize do
            @on_enqueued_invoked = false
            @on_started_invoked = false
            @on_finished_invoked = false
            @last_message = messages.last
          end
        end

        # @return [Boolean] is the coordinated work finished or not
        def finished?
          @running_jobs.zero?
        end

        # Runs synchronized code once for a collective of virtual partitions prior to work being
        # enqueued
        def on_enqueued
          @flow_lock.synchronize do
            return if @on_enqueued_invoked

            @on_enqueued_invoked = true

            yield(@last_message)
          end
        end

        # Runs given code only once per all the coordinated jobs upon starting first of them
        def on_started
          @flow_lock.synchronize do
            return if @on_started_invoked

            @on_started_invoked = true

            yield(@last_message)
          end
        end

        # Runs once when all the work that is suppose to be coordinated is finished
        # It runs once per all the coordinated jobs and should be used to run any type of post
        # jobs coordination processing execution
        def on_finished
          @flow_lock.synchronize do
            return unless finished?
            return if @on_finished_invoked

            @on_finished_invoked = true

            yield(@last_message)
          end
        end
      end
    end
  end
end
