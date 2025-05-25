# frozen_string_literal: true

# There has been at least few reports that Karafka (or rdkafka) under some combination of
# features and/or events returns same messages in one batch. To ensure this is not happening and
# to detect if it does, this detector hooks up to a low level event post-data fetch and validates
# that data targeting each topic partition is indeed not duplicated.
#
# It also checks just to be sure, that data for given partition matches the partition and topic
# mapping.
class DuplicationsDetector
  # @param spec_context [Object] main context
  def initialize(spec_context)
    @spec_context = spec_context
    @consumers_assignments = {}
    @mutex = Mutex.new
  end

  # @param event [Karafka::Core::Monitoring::Event]
  def on_connection_listener_fetch_loop_received(event)
    event[:messages_buffer].each do |topic_name, partition, messages|
      # Can happen when eof and no data
      next if messages.empty?

      counts = messages.group_by(&:offset).transform_values(&:size).values.uniq

      assert_equal([1], counts, "#{topic_name}##{partition}: #{counts}")

      messages.each do |message|
        assert_equal(
          topic_name,
          message.topic,
          "#{topic_name}##{partition}: #{message.topic}"
        )

        assert_equal(
          partition,
          message.partition,
          "#{topic_name}##{partition}: #{message.partition}"
        )
      end
    end
  end

  # Checks that things did not get messed up between polling and work distribution
  # @param event [Karafka::Core::Monitoring::Event]
  def on_consumer_consume(event)
    consumer = event[:caller]
    topic_name = consumer.topic.name
    partition = consumer.partition

    messages = consumer.messages
    counts = messages.group_by(&:offset).transform_values(&:size).values.uniq

    assert_equal([1], counts, "#{topic_name}##{partition}: #{counts}")
    assert_equal(1, counts.size)

    messages.each do |message|
      assert_equal(
        topic_name,
        message.topic,
        "#{topic_name}##{partition}: #{message.topic}"
      )

      assert_equal(
        partition,
        message.partition,
        "#{topic_name}##{partition}: #{message.partition}"
      )
    end

    # Ensures that a single consumer instance always consumers one topic partition, even
    # between batches
    @mutex.synchronize do
      set = [topic_name, partition]

      if @consumers_assignments[consumer.id]
        assert_equal(
          @consumers_assignments[consumer.id],
          set,
          "#{topic_name}##{partition}: #{@consumers_assignments[consumer.id]} vs. #{set}"
        )
      else
        @consumers_assignments[consumer.id] = set
      end
    end
  end

  private

  # @param args [Array] anything the spec context assertion accepts
  def assert_equal(*args)
    @spec_context.send(:assert_equal, *args)
  end
end
