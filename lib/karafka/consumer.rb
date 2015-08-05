require 'karafka/router'
# Main module namespace
module Karafka
  # Class that receive events
  class Consumer
    def initialize(brokers, zookeeper_hosts)
      @brokers = brokers
      @zookeeper_hosts = zookeeper_hosts
    end

    # Receive the messages
    def receive
      loop do
        fetch
      end
    end

    private

    def fetch
      consumer_groups.each do |group|
        group.fetch_loop do |_partition, bulk|
          break if bulk.empty?
          bulk.each { |m| Karafka::Router.new(group.topic, m.value) }
        end
      end
    end

    def validate_info_uniquness
    end

    def consumer_groups
      groups = []
      klasses_options.each do |klass|
        begin
          groups << Poseidon::ConsumerGroup.new(
            klass.group,
            @brokers,
            @zookeeper_hosts,
            klass.topic,
            socket_timeout_ms: 50_000 # Karafka.config.socket_timeout_ms
          )
        rescue Poseidon::Errors::UnableToFetchMetadata
          return groups
        end
      end
      groups
    end
    #
    def klasses_options
      Karafka::BaseController.descendants.map do |klass|
        OpenStruct.new(topic: klass.topic, group: klass.group)
      end
    end
  end
end
