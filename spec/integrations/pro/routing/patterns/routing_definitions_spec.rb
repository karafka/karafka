# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should have ability to define patterns in routes for dynamic topics subscriptions
# It should assign virtual topics and patters to the appropriate consumer groups

setup_karafka

Consumer1 = Class.new
Consumer2 = Class.new

draw_routes(create_topics: false) do
  topic 'test' do
    consumer Consumer1
  end

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

assert_equal 2, Karafka::App.routes.size
assert_equal 3, Karafka::App.routes.map(&:topics).flatten.map(&:to_a).flatten.size
assert_equal 'test', Karafka::App.routes.first.topics.first.name
assert !Karafka::App.routes.first.topics.first.patterns.active?
assert Karafka::App.routes.first.topics.last.name.include?('karafka-pattern-')
assert Karafka::App.routes.last.topics.first.name.include?('karafka-pattern-')
assert Karafka::App.routes.first.topics.last.patterns.active?
assert Karafka::App.routes.first.topics.last.patterns.matcher?
assert Karafka::App.routes.last.topics.last.patterns.active?
assert Karafka::App.routes.last.topics.last.patterns.matcher?
