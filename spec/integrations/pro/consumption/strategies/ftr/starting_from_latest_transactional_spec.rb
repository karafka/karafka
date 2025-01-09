# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# A spec that illustrates usage of a filter that will ensure that when we start Karafka, we always
# start from the latest offset even if it is a transactional one. We can start from the
# high-watermark - 1 on transactional but it will just wait for more data

setup_karafka do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
end

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

    return if @executed

    @executed = true
    @applied = true

    high_watermark = Karafka::Admin.read_watermark_offsets(@topic, @partition).last

    @cursor = Karafka::Messages::Seek.new(@topic, @partition, high_watermark - 1)

    messages.clear

    DT[:clicked] << true
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
  if DT.key?(:clicked) && !DT.key?(:second)
    produce_many(DT.topic, DT.uuids(1))
    DT[:second] << true
  end

  DT[:offsets].size >= 1
end

assert_equal DT[:offsets], [101]
