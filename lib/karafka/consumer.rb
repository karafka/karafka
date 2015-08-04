require 'karafka/router'
# Main module namespace
module Karafka
  # Class that receive events
  class Consumer
    def initialize(group_name, brokers, zookeeper_hosts)
      @group_name = group_name
      @brokers = brokers
      @zookeeper_hosts = zookeeper_hosts
    end

    # Receive the messages
    def receive
      fetch_consumer_group
      # fetch(consumer_group)
    end

    private

    # Creates consumer group
    def fetch_consumer_group
      threads = []
      Karafka::BaseController.descendants.collect(&:topic).each do |topic_name|
       group =  Poseidon::ConsumerGroup.new(
          @group_name,
          @brokers,
          @zookeeper_hosts,
          topic_name,
          socket_timeout_ms: 50_000 # Karafka.config.socket_timeout_ms
        )
       threads << Thread.new do
         group.fetch_loop do |_partition, bulk|
           bulk.each { |m| Karafka::Router.new(topic_name, m.value) }
         end
       end

      end
      threads.each(&:join)
    end

    # Fetch messages and route them to needed controller
    def fetch(consumer_group)
      consumer_group.fetch_loop do |_partition, bulk|
        bulk.each { |m| Karafka::Router.new(consumer_group.topic_name, m.value) }
      end
    end
  end
end

#
# # Create a consumer group
# group1 = Poseidon::ConsumerGroup.new "my-group", ["host1:9092", "host2:9092"], ["host1:2181", "host2:2181"], "my-topic"
#
# # Start consuming "my-topic" in a background thread
# thread1 = Thread.new do
#   group1.fetch_loop do |partition, messages|
#     puts "Consumer #1 fetched #{messages.size} from #{partition}"
#   end
# end
#
# # Create a second consumer group
# group2 = Poseidon::ConsumerGroup.new "my-group", ["host1:9092", "host2:9092"], ["host1:2181", "host2:2181"], "my-topic"
#
# # Now consuming all partitions of "my-topic" in parallel
# thread2 = Thread.new do
#   group2.fetch_loop do |partition, messages|
#     puts "Consumer #2 fetched #{messages.size} from #{partition}"
#   end
# end
#
# # Join threads, loop forever
# [thread1, thread2].each(&:join)