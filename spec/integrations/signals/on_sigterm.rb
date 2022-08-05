# frozen_string_literal: true

# When Karafka receives sigterm, it should stop

setup_karafka

class Consumer < Karafka::BaseConsumer
  # Do nothing
  def consume; end
end

draw_routes(Consumer)

produce(DT.topic, '1')

Thread.new do
  sleep(5)

  Process.kill('TERM', Process.pid)
end

start_karafka_and_wait_until { false }

# We don't have to do anything here. In case of a failure Karafka will not stop and will be killed
# with notification by the supervisor.
