# frozen_string_literal: true

# We should be able to define custom frequencies and it should work.
# It should use defaults where nothing defined

setup_karafka do |config|
  config.max_messages = 1
  config.max_wait_time = 100
end

class Consumer < Karafka::BaseConsumer
  def consume; end

  def tick
    DT[topic.name] << Time.now.to_f
  end
end

draw_routes do
  defaults do
    consumer Consumer
  end

  topic DT.topics[0] do
    # every 5 seconds (default tick interval)
    periodic true
  end

  topic DT.topics[1] do
    periodic frequency: 100
  end

  topic DT.topics[2] do
    periodic frequency: 1_000
  end
end

start_karafka_and_wait_until do
  DT.topics.first(3).all? do |name|
    DT[name].size >= 5
  end
end

[
  [5_000, 10_000],
  [100, 1_000],
  [1_000, 2_000]
].each_with_index do |(min, max), index|
  previous = nil

  DT[DT.topics[index]].each do |time|
    unless previous
      previous = time

      next
    end

    delta = (time - previous) * 1_000

    assert delta >= min, [delta, min]
    assert delta <= max, [delta, max]

    previous = time
  end
end
