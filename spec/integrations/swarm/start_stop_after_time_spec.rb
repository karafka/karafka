# frozen_string_literal: true

# We should be able to create a swarm where one of the processes gets assignment and consumes
# messages. After this we should be able to stop everything.

setup_karafka

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    WRITER.puts('1')
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until(mode: :swarm) do
  READER.gets
end
