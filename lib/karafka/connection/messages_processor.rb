# frozen_string_literal: true

module Karafka
  module Connection
    # Class that consumes messages for which we listen
    module MessagesProcessor
      class << self
        # Processes messages (does something with them)
        # It will either schedule or run a proper controller action for messages
        # @note This should be looped to obtain a constant listening
        # @note We catch all the errors here, to make sure that none failures
        #   for a given consumption will affect other consumed messages
        #   If we wouldn't catch it, it would propagate up until killing the Celluloid actor
        # @param group_id [String] group_id of a group from which a given message came
        # @param kafka_messages [Array<Kafka::FetchedMessage>] raw messages fetched from kafka
        def process(group_id, kafka_messages)
          # @note We always get messages by topic and partition so we can take topic from the
          # first one and it will be valid for all the messages
          # We map from incoming topic name, as it might be namespaced, etc.
          # @see topic_mapper internal docs
          mapped_topic = Karafka::App.config.topic_mapper.incoming(kafka_messages[0].topic)
          # @note We search based on the topic id - that is a combination of group id and
          # topic name
          controller = Karafka::Routing::Router.build("#{group_id}_#{mapped_topic}")
          handler = controller.topic.batch_processing ? :process_batch : :process_each

          send(handler, controller, mapped_topic, kafka_messages)
          # This is on purpose - see the notes for this method
          # rubocop:disable RescueException
        rescue Exception => e
          # rubocop:enable RescueException
          Karafka.monitor.notice_error(self, e)
        end

        private

        # Processes whole batch in one request (all at once)
        # @param controller [Karafka::BaseController] base controller descendant
        # @param mapped_topic [String] mapped topic name
        # @param kafka_messages [Array<Kafka::FetchedMessage>] raw messages from kafka
        def process_batch(controller, mapped_topic, kafka_messages)
          messages_batch = kafka_messages.map do |kafka_message|
            # Since we support topic mapping (for Kafka providers that require namespaces)
            # we have to overwrite topic with our mapped topic version
            # @note For the default mapper, it will be the same as topic
            # @note We have to use instance_variable_set, as the Kafka::FetchedMessage does not
            #   provide attribute writers
            kafka_message.instance_variable_set(:'@topic', mapped_topic)
            kafka_message
          end

          controller.params_batch = messages_batch

          Karafka.monitor.notice(self, messages_batch)

          controller.schedule
        end

        # Processes messages one by one (like with std http requests)
        # @param controller [Karafka::BaseController] base controller descendant
        # @param mapped_topic [String] mapped topic name
        # @param kafka_messages [Array<Kafka::FetchedMessage>] raw messages from kafka
        def process_each(controller, mapped_topic, kafka_messages)
          kafka_messages.each do |kafka_message|
            # @note This is a simple trick - we just process one after another, but in order
            # not to handle everywhere both cases (single vs batch), we just "fake" batching with
            # a single message for each
            process_batch(controller, mapped_topic, [kafka_message])
          end
        end
      end
    end
  end
end
