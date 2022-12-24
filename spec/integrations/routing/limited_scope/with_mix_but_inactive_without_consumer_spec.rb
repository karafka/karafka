# frozen_string_literal: true

# When we have inactive topics, they should be ok without consumer defined

setup_karafka

draw_routes(create_topics: false) do
  consumer_group 'a' do
    subscription_group 'b' do
      topic 'c' do
        active false
      end
    end
  end

  consumer_group 'd' do
    subscription_group 'e' do
      topic 'f' do
        consumer Class.new

        # This is not needed but we nonetheless check such a case
        active true
      end
    end
  end
end

# This should not fail as one consumer group topic is active and with consumer
start_karafka_and_wait_until do
  true
end
