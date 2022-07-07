# frozen_string_literal: true

module Karafka
  module Pro
    module Processing
      # Pro coordinator that provides extra orchestration methods useful for parallel processing
      # within the same partition
      class Coordinator < ::Karafka::Processing::Coordinator
        # @param args [Object] anything the base coordinator accepts
        def initialize(*args)
          super
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
            @on_started_invoked = false
            @on_finished_invoked = false
            @first_message = messages.first
            @last_message = messages.last
          end
        end

        # @return [Boolean] is the coordinated work finished or not
        def finished?
          @running_jobs.zero?
        end

        # Runs given code only once per all the coordinated jobs upon starting first of them
        def on_started
          @flow_lock.synchronize do
            return if @on_started_invoked

            @on_started_invoked = true

            yield(@first_message, @last_message)
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

            yield(@first_message, @last_message)
          end
        end
      end
    end
  end
end
