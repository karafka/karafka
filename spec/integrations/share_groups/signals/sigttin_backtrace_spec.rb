# frozen_string_literal: true

# Share group (KIP-932): when Karafka receives SIGTTIN, it should log the threads backtraces
# (including the share listener thread) when the logger listener is enabled.

strio = StringIO.new

setup_karafka do |config|
  config.logger = Logger.new(strio)
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each { |message| mark_as_accepted(message) }
    DT[:consumed] << true
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

produce(DT.topic, "1")

Thread.new do
  sleep(0.1) while DT[:consumed].empty?

  Process.kill("TTIN", Process.pid)

  sleep(1)

  Process.kill("INT", Process.pid)
end

start_karafka_and_wait_until { false }

assert strio.string.include?("Received SIGTTIN system signal")
assert strio.string.include?("Thread TID-")
assert strio.string.include?("karafka.share_listener")
