# frozen_string_literal: true

# Karafka should be able to trigger a rebalance for a consumer group using Admin API

setup_karafka

class RebalanceTrackingConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << {
        offset: message.offset,
        partition: message.partition
      }
    end
  end

  def on_revoked
    DT[:rebalances] << {
      type: :revoked,
      time: Time.now.to_f
    }
  end
end

draw_routes(RebalanceTrackingConsumer)

# Produce some messages
messages = DT.uuids(5)
produce_many(DT.topic, messages)

# Trigger rebalance from a separate thread while Karafka is still running
rebalance_thread = Thread.new do
  sleep(0.5) until DT.key?(:consumed)

  Karafka::Admin.trigger_rebalance(DT.consumer_group)
end

# Start consumer and wait for initial consumption
# If no rebalance on admin, this will hang and spec will timeout
start_karafka_and_wait_until do
  DT.key?(:rebalances)
end

# Wait for rebalance thread to complete
rebalance_thread.join
