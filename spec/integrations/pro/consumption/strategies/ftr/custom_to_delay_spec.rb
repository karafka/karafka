# frozen_string_literal: true

# Karafka should allow us to use throttling engine to implement delayed jobs

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << [message.offset, Time.now.utc]
    end
  end
end

class DelayThrottler
  include Karafka::Core::Helpers::Time

  attr_reader :message

  def initialize
    # 5 seconds
    @min_delay = 5
  end

  def filter!(messages)
    @throttled = false
    @message = nil

    now = float_now

    messages.delete_if do |message|
      @throttled = (now - message.timestamp.to_f) < @min_delay

      @message = message if @throttled && @message.nil?

      @throttled
    end
  end

  def filtered?
    throttled?
  end

  def throttled?
    @throttled
  end

  def expired?
    timeout < 0
  end

  def timeout
    # Needs to be in ms
    @min_delay * 1_000 - (float_now - @message.timestamp.to_f) * 1_000
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    filter(-> { DelayThrottler.new })
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  sleep(15)
end

p DT[0]
