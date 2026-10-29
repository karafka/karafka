# frozen_string_literal: true

# Karafka should allow us to tag share consumers (KIP-932) runtime operations and should allow us
# to track those tags from any external location, the same way as for consumer groups.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      tags.add(:current_payload, message.raw_payload)
      # Gives the external tracker a chance to observe the tag
      sleep(0.1)
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

elements = DT.uuids(10)
produce_many(DT.topic, elements)

Karafka::App.monitor.subscribe("consumer.consume") do |event|
  DT[:caller] << event[:caller]
end

Thread.new do
  loop do
    sleep(0.01) while DT[:caller].first.nil?

    DT[:caller].first.tags.to_a.each do |tag|
      DT[:tags] << tag
    end

    sleep(0.01)
  end
end

start_karafka_and_wait_until do
  DT[:tags].uniq.size >= 5
end

assert (DT[:tags].uniq - elements).empty?, DT[:tags].uniq
