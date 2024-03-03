# frozen_string_literal: true

# We should be able to assign to ourselves multiple topics in one CG

setup_karafka

class Consumer1 < Karafka::BaseConsumer
  def consume
    DT[:t1] = true
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    DT[:t2] = true
  end
end

draw_routes do
  topic DT.topics.first do
    consumer Consumer1
    assign(true)
  end

  topic DT.topics.last do
    consumer Consumer2
    assign(true)
  end
end

produce_many(DT.topics.first, DT.uuids(1))
produce_many(DT.topics.last, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:t1) && DT.key?(:t2)
end
