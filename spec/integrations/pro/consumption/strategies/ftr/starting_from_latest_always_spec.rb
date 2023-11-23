# frozen_string_literal: true

# A spec that illustrates usage of a filter that will ensure that when we start Karafka, we always
# start from the latest message despite any previous assignments
# It should move to latest and then move forward

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |msg|
      DT[:offsets] << msg.offset
    end
  end
end

class Jumper < Karafka::Pro::Processing::Filters::Base
  def initialize(topic, partition)
    super()
    @topic = topic.name
    @partition = partition
  end

  def apply!(messages)
    @applied = false
    @cursor = nil

    return if @seeked

    @seeked = true
    @applied = true

    high_watermark = Karafka::Admin.read_watermark_offsets(@topic, @partition).last

    @cursor = Karafka::Messages::Seek.new(@topic, @partition, high_watermark - 1)

    messages.clear
  end

  def action
    applied? ? :seek : :skip
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter(->(topic, partition) { Jumper.new(topic, partition) })
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  if DT[:offsets].size == 1 && !DT.key?(:second)
    produce_many(DT.topic, DT.uuids(1))
    DT[:second] << true
  end

  DT[:offsets].size >= 2
end

assert_equal DT[:offsets], [99, 100]
