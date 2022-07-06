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

        # @param _messages [Array<Karafka::Messages::Message>]
        def start(messages)
          super

          @mutex.synchronize do
            @first_message = messages.first
            @last_message = messages.last
          end
        end

        # @return [Boolean] is the coordinated work finished or not
        def finished?
          @running_jobs.zero?
        end

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
