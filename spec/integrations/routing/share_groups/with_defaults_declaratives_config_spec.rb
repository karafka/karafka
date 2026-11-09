# frozen_string_literal: true

# Routing defaults with `config(...)` should apply to share-group topics like to consumer-group
# topics, instead of failing when a share group is drawn.

setup_karafka

draw_routes(create_topics: false) do
  defaults do
    config(partitions: 3)
  end

  consumer_group "cg" do
    topic "regular" do
      active(false)
      consumer Class.new(Karafka::BaseConsumer)
    end
  end

  share_group "sg" do
    topic "share-topic" do
      active(false)
      consumer Class.new(Karafka::ShareConsumer)
    end
  end
end

share_topic = Karafka::App.routes.find(&:share_group?).topics.first

assert_equal 3, share_topic.declaratives.partitions
assert_equal 3, Karafka::App.declaratives.find_topic("share-topic").partitions
