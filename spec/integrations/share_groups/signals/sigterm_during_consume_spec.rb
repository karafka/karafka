# frozen_string_literal: true

# Share group (KIP-932): when SIGTERM is sent while a share consumer is processing, Karafka should
# let the batch finish, run the shutdown hook and stop gracefully.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    DT[:consuming] << true
    sleep(2)

    messages.each do |message|
      DT[:accepted] << message.offset
      mark_as_accepted(message)
    end
  end

  def shutdown
    DT[:shutdown] << true
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

produce_many(DT.topic, DT.uuids(5))

Thread.new do
  sleep(0.1) while DT[:consuming].empty?

  Process.kill("TERM", Process.pid)
end

start_karafka_and_wait_until { false }

# The in-flight batch was finished before shutting down
assert_equal [true], DT[:consuming]
assert DT[:accepted].size >= 1
assert_equal [true], DT[:shutdown]
