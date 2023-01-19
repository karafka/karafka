# frozen_string_literal: true

# Karafka should use client_id for kafka.client.id if kafka.client.id is not provided

setup_karafka do |config|
  config.client_id = 'test-app'
end

assert_equal Karafka::App.config.kafka[:'client.id'], 'test-app'
