# frozen_string_literal: true

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    100.times do
      Karafka::Instrumentation::AssignmentsTracker.instance.inspect
    end

    DT[:done] << true
  end
end

draw_routes do
  DT.consumer_groups[0..100].each do |cg|
    consumer_group cg do
      topic DT.topic do
        consumer Consumer
      end
    end
  end
end

produce(DT.topic, rand.to_s)

start_karafka_and_wait_until do
  DT[:done].size >= 100
end
