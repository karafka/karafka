# frozen_string_literal: true

# Karafka should allow for usage of custom throttlers per topic

setup_karafka

class Consumer1 < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << message.offset
    end
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[1] << message.offset
    end
  end
end

# This is a funny throttler because it will always allow only one message and if more, it will
# throttle.
class BaseThrottler
  attr_reader :message

  def throttle!(messages)
    @throttled = false
    @message = nil

    i = -1

    messages.delete_if do |message|
      i += 1

      @throttled = i > 0

      @message = message if @throttled && @message.nil?

      next true if @throttled

      false
    end
  end

  def throttled?
    @throttled
  end

  def expired?
    false
  end

  def timeout
    self.class.to_s.split('').last.to_i * 1_000
  end
end

MyThrottler1 = Class.new(BaseThrottler)
MyThrottler10 = Class.new(BaseThrottler)

draw_routes do
  topic DT.topics[0] do
    consumer Consumer1
    throttling(throttler_class: MyThrottler1)
  end

  topic DT.topics[1] do
    consumer Consumer2
    throttling(throttler_class: MyThrottler10)
  end
end

2.times do |i|
  elements = DT.uuids(100)
  produce_many(DT.topics[i], elements)
end

start_karafka_and_wait_until do
  sleep(15)
end

assert DT[1].count > DT[0].count * 2
