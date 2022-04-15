# frozen_string_literal: true

# Karafka process when stopped and started and configured with static membership should pick up
# the assigned work. It should not be reassigned to a different process.
# Karafka should maintain all the ordering and should not have duplicated.

require 'securerandom'

RUN = SecureRandom.uuid.split('-').first

setup_karafka do |config|
  config.initial_offset = 'latest'
  config.kafka[:'group.instance.id'] = SecureRandom.uuid
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector.data[:process1] << message
    end
  end
end

draw_routes do
  consumer_group 'integrations_1_02' do
    topic 'integrations_1_02' do
      consumer Consumer
    end
  end
end

Thread.new do
  nr = 0

  loop do
    begin
      2.times do |i|
        produce('integrations_1_02', "#{RUN}-#{nr}-#{i}", partition: i)
      end
    rescue WaterDrop::Errors::ProducerClosedError
      sleep(5)
      retry
    end

    nr += 1

    sleep(0.2)
  end
end

start_karafka_and_wait_until do
  DataCollector.data[:process1].size >= 5
end

setup_karafka do |config|
  config.producer = nil
end

start_karafka_and_wait_until do
  p Karafka::App.producer.status.closed?
  DataCollector.data[:process1].size >= 50
end
