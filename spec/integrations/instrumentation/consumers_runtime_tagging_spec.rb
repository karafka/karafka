# frozen_string_literal: true

# Karafka should allow us to tag consumers runtime operations and should allow us to track those
# tags whenever we need from any external location.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      tags.add(:current_offset, message.offset)
      # This allows us to track tags easily
      # Not really the use-case but helps simplify the spec
      sleep(0.1)
    end
  end
end

draw_routes(Consumer)

elements = DT.uuids(10)
produce_many(DT.topic, elements)

Thread.new do
  loop do
    sleep(0.01) while DT[:caller].first.nil?

    DT[:caller].first.tags.to_a.each do |tag|
      DT[:offsets] << tag
    end

    sleep(0.01)
  end
end

Karafka::App.monitor.subscribe('consumer.consume') do |event|
  DT[:caller] << event[:caller]
end

start_karafka_and_wait_until do
  # We don't expect al 10 because Github actions sometimes hangs and we don't want to make this
  # spec extremely time sensitive
  DT[:offsets].uniq.size >= 5
end

assert DT[:offsets].uniq.count > 0
