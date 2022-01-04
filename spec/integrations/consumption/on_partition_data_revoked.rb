# frozen_string_literal: true

# Karafka should trigger an on_revoked action when a partition is being taken from us

setup_karafka

elements = Array.new(100) { SecureRandom.uuid }

DataCollector.data[:revoked] = Concurrent::Array.new
DataCollector.data[:pre] = Set.new
DataCollector.data[:post] = Set.new

class Consumer < Karafka::BaseConsumer
  def consume
    if DataCollector.data[:revoked].empty?
      DataCollector.data[:pre] << messages.metadata.partition
    else
      DataCollector.data[:post] << messages.metadata.partition
    end
  end

  def revoked
    DataCollector.data[:revoked] << { messages.metadata.partition => Time.now }
  end
end

Karafka::App.routes.draw do
  consumer_group 'integrations_1_03' do
    topic 'integrations_1_03' do
      consumer Consumer
      manual_offset_management true
    end
  end
end

elements.each { |data| produce('integrations_1_03', data, partition: rand(0..2)) }

Thread.new do
  sleep 5

  config = {
    :"bootstrap.servers" => "localhost:9092",
    :"group.id" => Karafka::App.consumer_groups.first.id,
    'auto.offset.reset' => 'earliest'
  }
  consumer = Rdkafka::Config.new(config).consumer
  consumer.subscribe('integrations_1_03')
  consumer.each {}
end

start_karafka_and_wait_until do
  !DataCollector.data[:post].empty?
end

p DataCollector.data
