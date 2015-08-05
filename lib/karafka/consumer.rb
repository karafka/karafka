require 'karafka/router'
# Main module namespace
module Karafka
  # Class that receive events
  class Consumer
    def initialize( brokers, zookeeper_hosts)
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
      loop do
        consumer_groups.each do |group|
          group.fetch_loop do |_partition, bulk|
            break if bulk.empty?
            bulk.each { |m| Karafka::Router.new(group.topic, m.value) }
          end
        end
      end
    end

    def consumer_groups
      klasses_options = Karafka::BaseController.descendants.map do
        |klass| OpenStruct.new(topic: klass.topic, group: klass.group)
      end

      groups = []
      klasses_options.each do |klass|
        groups << Poseidon::ConsumerGroup.new(
          klass.group,
          @brokers,
          @zookeeper_hosts,
          klass.topic,
          socket_timeout_ms: 50_000 # Karafka.config.socket_timeout_ms
        )
      end
      groups
    end

    # Fetch messages and route them to needed controller
    def fetch(consumer_group)
      consumer_group.fetch_loop do |_partition, bulk|
        bulk.each { |m| Karafka::Router.new(consumer_group.topic_name, m.value) }
      end
    end
  end
end
