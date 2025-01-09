# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When customizing the error pausing strategy, each topic should obey its own limitations

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.pause_timeout = 1_000
  config.pause_max_timeout = 10_000
  config.pause_with_exponential_backoff = false
  config.max_wait_time = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[messages.metadata.topic.to_s] << Time.now.to_f

    raise
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
  end

  topic DT.topics[1] do
    consumer Consumer
    pause(
      timeout: 100,
      max_timeout: 2_000,
      with_exponential_backoff: true
    )
  end

  topic DT.topics[2] do
    consumer Consumer
    pause(
      timeout: 5_000,
      max_timeout: 5_000,
      with_exponential_backoff: false
    )
  end
end

3.times { |i| produce(DT.topics[i], '0') }

start_karafka_and_wait_until do
  DT.data.size >= 3 && DT.data.all? { |_, v| v.size >= 5 }
end

previous = nil

DT[DT.topics[0]].each do |time|
  unless previous
    previous = time
    next
  end

  diff = time - previous

  assert diff >= 1, diff
  assert diff <= 5, diff

  previous = time
end

previous = nil

DT[DT.topics[1]].each do |time|
  unless previous
    previous = time
    next
  end

  diff = time - previous

  assert diff >= 0.1, diff
  assert diff <= 5, diff

  previous = time
end

previous = nil

DT[DT.topics[2]].each do |time|
  unless previous
    previous = time
    next
  end

  diff = time - previous

  assert diff >= 5, diff

  previous = time
end
