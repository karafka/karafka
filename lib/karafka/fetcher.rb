# frozen_string_literal: true

module Karafka
  # Class used to run the Karafka consumer and handle shutting down, restarting etc
  # @note Creating multiple fetchers will result in having multiple connections to the same
  #   topics, which means that if there are no partitions, it won't use them.
  class Fetcher
    class << self
      # Starts listening on all the listeners asynchronously
      # Fetch loop should never end, which means that we won't create more actor clusters
      # so we don't have to terminate them
      def call
        threads = listeners.map do |listener|
          # We abort on exception because there should be an exception handling developed for
          # each listener running in separate threads, so the exceptions should never leak
          # and if that happens, it means that something really bad happened and we should stop
          # the whole process
          Thread
            .new { listener.call }
            .tap { |thread| thread.abort_on_exception = true }
        end

        # We aggregate threads here for a supervised shutdown process
        threads.each { |thread| Karafka::Server.consumer_threads << thread }
        threads.each(&:join)
      # If anything crashes here, we need to raise the error and crush the runner because it means
      # that something terrible happened
      rescue StandardError => e
        Karafka.monitor.instrument('fetcher.call.error', caller: self, error: e)
        Karafka::App.stop!
        raise e
      end

      private

      # @return [Array<Karafka::Connection::Listener>] listeners that will consume messages
      def listeners
        @listeners ||= App.consumer_groups.active.map do |consumer_group|
          Karafka::Connection::Listener.new(consumer_group)
        end
      end
    end
  end
end
