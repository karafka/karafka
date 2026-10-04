# frozen_string_literal: true

# Share group (KIP-932) consumption can be time bound: Karafka consumes for a given time, stops on
# request in a timely manner and everything consumed in that time is accepted.

setup_karafka

# How long do we want to process stuff before shutting down Karafka process
MAX_TIME = 10

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:accepted] << message.raw_payload
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

# Sends some data so we know all is good
elements = DT.uuids(100)
produce_many(DT.topic, elements)

# Stop after 10 seconds
Thread.new do
  sleep(MAX_TIME)
  Karafka::Server.stop
end

time_before = Process.clock_gettime(Process::CLOCK_MONOTONIC)

Karafka::Server.run

time_after = Process.clock_gettime(Process::CLOCK_MONOTONIC)

assert_equal elements.sort, DT[:accepted].sort
# We will give Karafka 5 seconds to stop
lag = time_after - time_before - MAX_TIME
assert lag < 5, lag
