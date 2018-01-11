# frozen_string_literal: true

module Karafka
  # Class used to run the Karafka consumer and handle shutting down, restarting etc
  # @note Creating multiple fetchers will result in having multiple connections to the same
  #   topics, which means that if there are no partitions, it won't use them.
  class Fetcher
    # Starts listening on all the listeners asynchronously
    # Fetch loop should never end, which means that we won't create more actor clusters
    # so we don't have to terminate them
    def fetch_loop
      threads = listeners.map do |listener|
        # We abort on exception because there should be an exception handling developed for
        # each listener running in separate threads, so the exceptions should never leak
        # and if that happens, it means that something really bad happened and we should stop
        # the whole process
        Thread
          .new { listener.fetch_loop(delegator) }
          .tap { |thread| thread.abort_on_exception = true }
      end

      # We aggregate threads here for a supervised shutdown process
      threads.each { |thread| Karafka::Server.consumer_threads << thread }
      threads.each(&:join)
    # If anything crashes here, we need to raise the error and crush the runner because it means
    # that something really bad happened
    rescue StandardError => e
      Karafka.monitor.notice_error(self.class, e)
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

    # @return [Proc] proc that should be executed when a messages arrive
    # @yieldparam messages [Array<Kafka::FetchedMessage>] messages from kafka (raw)
    # @note What happens here is a delegation of processing to a proper processor based on the
    #   incoming messages characteristics
    def delegator
      lambda do |group_id, messages|
        Karafka::Connection::Delegator.call(group_id, messages)
      end
    end
  end
end
