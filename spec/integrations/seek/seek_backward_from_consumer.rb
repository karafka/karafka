# frozen_string_literal: true

# This spec aims to test seeking process. We use seek to process first message out of all and then
# we move backwards till 0

setup_karafka

elements = Array.new(10) { SecureRandom.uuid }
elements.each { |data| produce(DataCollector.topic, data) }

class Consumer < Karafka::BaseConsumer
  def initialize
    @backwards = false
    @ignore = false
    super
  end

  def consume
    return if @ignore

    if @backwards
      message = messages.first

      DataCollector[messages.metadata.partition] << message.offset
      seek(message.offset - 1)

      @ignore = true if message.offset.zero?
    elsif messages.last.offset == 9
      @backwards = true
      seek(9)
    end
  end
end

draw_routes(Consumer)

start_karafka_and_wait_until do
  DataCollector[0].size >= 10
end

assert_equal (0..9).to_a.reverse, DataCollector[0]
