# frozen_string_literal: true

# When many threads request a stop at the same time, only one of them should run the stop
# sequence. The others should return without running it.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed] << true
  end
end

draw_routes(Consumer)

produce(DT.topic, "1")

Karafka.producer.singleton_class.prepend(
  Module.new do
    def close(...)
      DT[:closes] << true
      super
    end
  end
)

stoppers = []

Thread.new do
  sleep(0.1) while DT[:consumed].empty?

  gate = Queue.new
  stoppers = Array.new(10) do
    Thread.new do
      gate.pop
      Karafka::Server.stop
    end
  end

  stoppers.size.times { gate << true }
end

Karafka::Server.run

stoppers.each(&:join)

assert_equal 1, DT[:closes].size
