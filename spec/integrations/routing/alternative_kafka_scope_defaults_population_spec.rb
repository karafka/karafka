# frozen_string_literal: true

# When we define alternative kafka cluster setup, it also should use same defaults

setup_karafka

draw_routes(create_topics: false) do
  topic 'topic1' do
    consumer(Karafka::BaseConsumer)
  end

  topic 'topic2' do
    consumer(Karafka::BaseConsumer)
    kafka('bootstrap.servers': '127.0.0.2:9092')
  end
end

c1 = Karafka::App.subscription_groups.values[0][0].kafka
c2 = Karafka::App.subscription_groups.values[0][1].kafka

assert c1.key?(:'max.poll.interval.ms')
assert c2.key?(:'max.poll.interval.ms')

assert c1[:'bootstrap.servers'] != c2[:'bootstrap.servers']
