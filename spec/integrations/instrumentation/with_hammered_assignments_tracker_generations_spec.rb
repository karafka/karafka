# frozen_string_literal: true

# AssignmentsTracker generations should remain stable and not crash when accessed concurrently
# from multiple consumer groups during message processing

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    100.times do
      gens = Karafka::Instrumentation::AssignmentsTracker.instance.generations
      gens.each_value { |partitions| partitions.each_value { |gen| raise if gen < 1 } }

      topic_obj = messages.metadata.topic
      partition = messages.metadata.partition
      gen = Karafka::Instrumentation::AssignmentsTracker.instance.generation(topic_obj, partition)
      raise if gen < 1
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
