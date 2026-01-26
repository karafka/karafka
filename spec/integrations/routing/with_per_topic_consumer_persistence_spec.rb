# frozen_string_literal: true

# We should be able to disable consumer persistence for all the topics by default but at the same
# time we should be able to customize things in a per topic basis.
#
# This can be useful when injecting extensions/plugins that would use routing.
#
# For example our Web-UI despite dev not having persistence needs to have persistence in order to
# be able to materialize and compute the states correctly

setup_karafka do |config|
  config.consumer_persistence = false
end

draw_routes(create_topics: false) do
  consumer_group :test1 do
    topic "topic1" do
      consumer Class.new
      consumer_persistence true
    end
  end

  consumer_group :test2 do
    topic "topic1" do
      consumer Class.new
      consumer_persistence false
    end

    topic "topic2" do
      consumer Class.new
    end
  end
end

assert_equal true, Karafka::App.consumer_groups.first.topics.first.consumer_persistence
assert_equal false, Karafka::App.consumer_groups.last.topics[0].consumer_persistence
assert_equal false, Karafka::App.consumer_groups.last.topics[1].consumer_persistence
