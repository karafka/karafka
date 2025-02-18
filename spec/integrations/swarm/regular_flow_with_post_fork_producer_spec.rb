# frozen_string_literal: true

# We should be able to use the regular producer with the inherited config to operate and send
# messages

setup_karafka

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    produce_sync(topic: DT.topic, payload: DT.uuid)

    WRITER.puts('1')
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until(mode: :swarm) do
  READER.gets
end
