# frozen_string_literal: true

# AssignmentsTracker should remain stable and not crash when inspected concurrently from
# multiple consumer groups during message processing and while those groups get assignments

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
  DT.groups[0...10].each do |cg|
    consumer_group cg do
      topic DT.topic do
        consumer Consumer
      end
    end
  end
end

produce(DT.topic, rand.to_s)

# Inspects while the rebalances of all the groups write their assignments
Thread.new do
  until DT[:done].size >= 10
    Karafka::Instrumentation::AssignmentsTracker.instance.inspect
    Thread.pass
  end
end

start_karafka_and_wait_until do
  DT[:done].size >= 10
end
