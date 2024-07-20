# frozen_string_literal: true

# Karafka should not use client_id for kafka.client.id if kafka.client.id is not provided, as it
# is injected when we define routes

setup_karafka do |config|
  config.client_id = 'test-app'
end

assert_equal Karafka::App.config.kafka[:'client.id'], nil

draw_routes(Karafka::BaseConsumer)

assert_equal Karafka::App.routes.first.subscription_groups.first.kafka[:'client.id'], 'test-app'
