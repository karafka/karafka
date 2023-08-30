# frozen_string_literal: true

# When combination of consumer groups, subscription groups and topics we want to run is such, that
# they do not exist all together, we need to raise an error.

setup_karafka

draw_routes(create_topics: false) do
  consumer_group 'a' do
    subscription_group 'b' do
      topic 'c' do
        consumer Class.new
      end
    end
  end

  consumer_group 'd' do
    subscription_group 'e' do
      topic 'f' do
        consumer Class.new
      end
    end
  end
end

activity_manager = Karafka::App.config.internal.routing.activity_manager

activity_manager.include(:consumer_groups, 'a')
activity_manager.include(:subscription_groups, 'e')
activity_manager.include(:topics, 'c')

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
