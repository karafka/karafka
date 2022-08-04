# frozen_string_literal: true

# Karafka in dev should pick up new topic creation fairly fast. It should not wait for 5 minutes

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DataCollector[0] << 1
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume; end
end

draw_routes do
  topic DataCollector.topic do
    consumer Consumer
  end

  # We need a second existing topic to which we send nothing, but only then Karafka will not
  # notice immediately the lack of the first topic
  topic 'integrations_00_02' do
    consumer Consumer2
  end
end

Thread.new do
  sleep 10
  produce(DataCollector.topic, '1')
end

start_karafka_and_wait_until do
  DataCollector[0].size >= 1
end

# No assertion needed as 5 minutes is more than we allow spec to run (3 minutes)
