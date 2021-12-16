# frozen_string_literal: true

# When we received no messages, on_shutdown should not happen

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DataCollector.data[0] << 1
  end

  def on_shutdown
    DataCollector.data[0] << 1
  end
end

Karafka::App.routes.draw do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      consumer Consumer
    end
  end
end

start_karafka_and_wait_until do
  sleep(2)
  true
end

assert_equal 0, DataCollector.data[0].size
