# frozen_string_literal: true

# When by default all topics are not active, we should be able to explicitely set it to active

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
  end
end

draw_routes(create_topics: false) do
  defaults do
    active false
  end

  topic "topic1"

  consumer_group :test do
    topic "topic2" do
      consumer Consumer
      active true
    end
  end
end

t1 = Karafka::App.consumer_groups.first.topics.first
t2 = Karafka::App.consumer_groups.last.topics.first

assert !t1.active?
assert t2.active?
