# frozen_string_literal: true

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume; end
end

draw_routes(create_topics: false) do
  defaults do
    active true
  end

  topic 'topic1' do
    consumer Consumer
  end

  consumer_group :test do
    topic 'topic2' do
      active false
    end
  end
end

t1 = Karafka::App.consumer_groups.first.topics.first
t2 = Karafka::App.consumer_groups.last.topics.first

assert t1.active?
assert !t2.active?
