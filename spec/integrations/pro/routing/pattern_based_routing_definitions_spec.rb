# frozen_string_literal: true

# We should have ability to define patterns in routes for dynamic topics subscriptions
# It should assign virtual topics and patters to the appropriate consumer groups

setup_karafka

Consumer1 = Class.new
Consumer2 = Class.new

draw_routes do
  pattern(/.*/) do
    consumer Consumer1
    long_running_job true
  end

  consumer_group :test do
    pattern(/ab/) do
      consumer Consumer2
      manual_offset_management true
    end
  end
end

assert_equal 2, Karafka::App.routes.count
assert_equal 2, Karafka::App.routes.map(&:topics).flatten.size

assert Karafka::App.routes.first.topics.first.name.include?('karafka-pattern-')
assert Karafka::App.routes.last.topics.first.name.include?('karafka-pattern-')
