# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When trying to exclude non existing consumer group, we should fail.

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

Karafka::App
  .config
  .internal
  .routing
  .activity_manager
  .exclude(:consumer_groups, 'x')

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
