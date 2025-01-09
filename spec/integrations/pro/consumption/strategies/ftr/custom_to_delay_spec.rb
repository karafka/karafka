# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should allow us to use throttling engine to implement delayed jobs

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << [message.offset, Time.now.utc]
    end
  end
end

class DelayThrottler < Karafka::Pro::Processing::Filters::Base
  include Karafka::Core::Helpers::Time

  attr_reader :cursor

  def initialize
    super
    # 5 seconds
    @min_delay = 5
  end

  def apply!(messages)
    @applied = false
    @cursor = nil

    now = float_now

    messages.delete_if do |message|
      @applied = (now - message.timestamp.to_f) < @min_delay

      @cursor = message if @applied && @cursor.nil?

      @applied
    end
  end

  def applied?
    @applied
  end

  def action
    if applied?
      timeout <= 0 ? :seek : :pause
    else
      :skip
    end
  end

  def timeout
    timeout = @min_delay * 1_000 - (float_now - @cursor.timestamp.to_f) * 1_000
    timeout <= 0 ? 0 : timeout
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    filter(->(*) { DelayThrottler.new })
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  sleep(15)
end

p DT[0]
