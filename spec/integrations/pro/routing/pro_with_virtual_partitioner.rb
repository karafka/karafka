# frozen_string_literal: true

# I should be able to define a topic consumption with virtual partitioner.
# It should not impact other jobs and the default should not have it.

setup_karafka do |config|
  config.license.token = pro_license_token
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topics[0] do
      consumer Class.new(Karafka::Pro::BaseConsumer)
      virtual_partitioner ->(msg) { msg.raw_payload }
    end

    topic DataCollector.topics[1] do
      consumer Class.new(Karafka::Pro::BaseConsumer)
    end

    topic DataCollector.topics[2] do
      consumer Class.new(Karafka::Pro::BaseConsumer)
    end
  end
end

assert Karafka::App.routes.first.topics[0].virtual_partitioner?
assert_equal false, Karafka::App.routes.first.topics[1].virtual_partitioner?
assert_equal false, Karafka::App.routes.first.topics[2].virtual_partitioner?
