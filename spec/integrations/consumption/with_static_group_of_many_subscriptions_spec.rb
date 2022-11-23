# frozen_string_literal: true

# Karafka should be able to use few subscription groups with static group memberships
# This requires us to inject extra postfix to group id per client and should happen automatically.

setup_karafka do |config|
  config.kafka[:'group.instance.id'] = SecureRandom.uuid
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:received] << true
  end
end

draw_routes do
  2.times do |i|
    subscription_group do
      topic DT.topics[i] do
        consumer Consumer
      end
    end
  end
end

2.times do |i|
  produce(DT.topics[i], rand.to_s)
end

start_karafka_and_wait_until do
  DT[:received].size >= 2
end
