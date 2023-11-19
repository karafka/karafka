# frozen_string_literal: true

# When all our topics are disabled in routing, we should not allow Karafka to run

setup_karafka

draw_routes(create_topics: false) do
  consumer_group 'a' do
    subscription_group 'b' do
      topic 'c' do
        active false
        consumer Class.new
      end
    end
  end

  consumer_group 'd' do
    subscription_group 'e' do
      topic 'f' do
        active false
        consumer Class.new
      end
    end
  end
end

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
