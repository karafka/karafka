# frozen_string_literal: true

# A share-group topic `max_wait_time` of 10 (the minimum) should pass routing validation.

setup_karafka

draw_routes(create_topics: false) do
  share_group "max_wait_time_share_group" do
    topic "max_wait_time_share_at_minimum" do
      consumer Class.new(Karafka::ShareConsumer)
      max_wait_time 10
    end
  end
end

assert_equal 10, Karafka::App.routes.first.topics.first.max_wait_time
