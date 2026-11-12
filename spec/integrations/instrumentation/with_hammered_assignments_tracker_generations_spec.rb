# frozen_string_literal: true

# AssignmentsTracker generations should remain stable and not crash when accessed concurrently
# from multiple consumer groups during message processing and while those groups get assignments

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    1_000.times do
      gens = Karafka::Instrumentation::AssignmentsTracker.instance.generations
      raise unless gens.frozen?

      gens.each_value do |partitions|
        raise unless partitions.frozen?

        partitions.each_value { |gen| raise if gen < 1 }
      end

      gen = Karafka::Instrumentation::AssignmentsTracker.instance.generation(topic, partition)
      raise if gen < 1
    end

    DT[:done] << true
  end
end

draw_routes do
  DT.groups[0...10].each do |cg|
    consumer_group cg do
      topic DT.topic do
        consumer Consumer
      end
    end
  end
end

produce(DT.topic, rand.to_s)

# Reads while the rebalances of all the groups write their generations
Thread.new do
  until DT[:done].size >= 10
    Karafka::Instrumentation::AssignmentsTracker.instance.generations
    Thread.pass
  end
end

start_karafka_and_wait_until do
  DT[:done].size >= 10
end
