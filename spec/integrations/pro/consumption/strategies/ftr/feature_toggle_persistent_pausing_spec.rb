# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Demonstrates persistent topic pausing using the Filtering API with feature toggles.
# This pattern allows pause state to survive restarts and rebalances, unlike Web UI pausing.

class FeatureToggle
  @flags = {}
  @mutex = Mutex.new

  class << self
    def enable(flag_name)
      @mutex.synchronize { @flags[flag_name] = true }
    end

    def disable(flag_name)
      @mutex.synchronize { @flags.delete(flag_name) }
    end

    def enabled?(flag_name)
      @mutex.synchronize { @flags.key?(flag_name) }
    end

    def reset!
      @mutex.synchronize { @flags.clear }
    end
  end
end

setup_karafka do |config|
  config.max_messages = 10
  config.pause.timeout = 1_000
  config.pause.max_timeout = 1_000
  config.pause.with_exponential_backoff = false
end

class FeatureTogglePauseFilter < Karafka::Pro::Processing::Filters::Base
  PAUSE_DURATION = 1_000

  def initialize(topic, partition)
    @topic = topic
    @partition = partition
    @paused = false
  end

  def apply!(messages)
    @cursor = nil
    @paused = false

    # No reason to pause anything when ther are no messages to consume in the first place
    return if messages.empty?

    flag_name = "pause_topic_#{@topic.name}"

    if FeatureToggle.enabled?(flag_name)
      @paused = true
      @cursor = messages.first
      messages.clear
    end
  end

  def applied?
    @paused
  end

  def action
    @paused ? :pause : :skip
  end

  def timeout
    @paused ? PAUSE_DURATION : nil
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:messages] << message.offset
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter(->(topic, partition) { FeatureTogglePauseFilter.new(topic, partition) })
  end
end

FeatureToggle.reset!

produce_many(DT.topic, DT.uuids(100))

FeatureToggle.enable("pause_topic_#{DT.topic}")

Thread.new { Karafka::Server.run }

sleep(10)

assert DT[:messages].size == 0

FeatureToggle.disable("pause_topic_#{DT.topic}")

sleep(0.1) until DT[:messages].size >= 90

Karafka::Server.stop

assert DT[:messages].size >= 90
assert_equal DT[:messages], DT[:messages].sort
