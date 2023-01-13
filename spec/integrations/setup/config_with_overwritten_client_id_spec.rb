# frozen_string_literal: true

# Karafka should not use client_id for kafka.client.id if kafka.client.id is provided

setup_karafka do |config|
  config.client_id = 'test-app'
  config.kafka[:'client.id'] = 'alternative-name'
end

assert_equal Karafka::App.config.kafka[:'client.id'], 'alternative-name'
