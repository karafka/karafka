# frozen_string_literal: true

ROOT_PATH = Pathname.new(File.expand_path(File.join(File.dirname(__FILE__), '../../../')))
require ROOT_PATH.join('spec/integrations_helper.rb')

# This spec aims to test seeking process. We use seek to process first message out of all and then
# we move backwards till 0

setup_karafka

elements = Array.new(10) { SecureRandom.uuid }
elements.each { |data| produce(DataCollector.topic, data) }

class Consumer < Karafka::BaseConsumer
  def initialize
    @backwards = false
    @ignore = false
  end

  def consume
    return if @ignore

    if @backwards
      message = messages.first

      DataCollector.data[messages.metadata.partition] << message.offset
      seek(message.offset - 1)

      if message.offset.zero?
        @ignore = true
      end
    else
      if messages.last.offset == 9
        @backwards = true
        seek(9)
      end
    end
  end
end

Karafka::App.routes.draw do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      consumer Consumer
    end
  end
end

start_karafka_and_wait_until do
  DataCollector.data[0].size >= 10
end

assert_equal (0..9).to_a.reverse, DataCollector.data[0]
