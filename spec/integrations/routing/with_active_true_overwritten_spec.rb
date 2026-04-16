# frozen_string_literal: true

# When by default all topics are active, we should be able to explicitely set it to inactive

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
  end
end

draw_routes(create_topics: false) do
  defaults do
    active true
  end

  topic "topic1" do
    consumer Consumer
  end

  consumer_group :test do
    topic "topic2" do
      active false
    end
  end
end

t1 = Karafka::App.routes.first.topics.first
t2 = Karafka::App.routes.last.topics.first

assert t1.active?
assert !t2.active?
