# frozen_string_literal: true

# Share group (KIP-932) records whose acquisition lock expires while Karafka still processes them
# are handed to another member of the group. This means duplicated processing: the other member
# gets them as a second delivery and accepts them, while Karafka still finishes its own work.

setup_karafka(allow_errors: %w[connection.client.acknowledgement.error])

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:karafka] << [message.raw_payload, message.delivery_count]
    end

    # Process longer than the 15 seconds lock
    sleep(20)

    messages.each { |message| mark_as_accepted(message) }

    DT[:karafka_done] = true
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group(configs: { "share.record.lock.duration.ms" => "15000" })

SUBSCRIPTION_GROUP = Karafka::App.subscription_groups.values.flatten.find { |sg| sg.group.share_group? }

produce_many(DT.topic, %w[a b])

member = Thread.new do
  # Join only once Karafka holds the records, so it is the one that gets them first
  sleep(0.1) while DT[:karafka].empty?

  consumer = Rdkafka::Config.new(SUBSCRIPTION_GROUP.kafka).share_consumer
  consumer.subscribe(DT.topic)

  until DT.key?(:stop)
    records = consumer.poll(100)

    records.each do |record|
      DT[:member] << [record.payload, record.delivery_count]
      consumer.acknowledge(record, :accept)
    end

    consumer.commit_sync unless records.empty?
  end

  consumer.close
end

start_karafka_and_wait_until do
  DT[:member].size >= 2 && DT.key?(:karafka_done)
end

DT[:stop] = true
member.join

assert_equal [["a", 1], ["b", 1]], DT[:karafka].sort
assert_equal [["a", 2], ["b", 2]], DT[:member].sort
