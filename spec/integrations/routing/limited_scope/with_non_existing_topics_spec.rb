# frozen_string_literal: true

# When trying to run non existing topics, we should fail.

setup_karafka

draw_routes(create_topics: false) do
  consumer_group 'a' do
    subscription_group 'b' do
      topic 'c' do
        consumer Class.new
      end
    end
  end
end

Karafka::App.config.internal.routing.active.topics = %w[x]

spotted = false

begin
  # This should fail with an exception
  start_karafka_and_wait_until do
    false
  end
rescue Karafka::Errors::InvalidConfigurationError
  spotted = true
end

assert spotted
