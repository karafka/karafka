require 'karafka/router'
# Main module namespace
module Karafka
  # Class that receive events
  class Consumer
    attr_reader :options

    def initialize(brokers, zookeeper_hosts)
      @brokers = brokers
      @zookeeper_hosts = zookeeper_hosts
      @options = klasses_options
    end

    # Receive the messages
    def receive
      # options = klasses_options
      groups = consumer_groups
      loop do
        groups.map do |g|
          Poseidon::ConsumerGroup
            .instance_variable_set(:@metadata,
              Poseidon::ClusterMetadata
                .new
                .tap { |m| m.update g.pool.fetch_metadata([g.topic]) })
        end
        fetch(groups)
      end
    end

    private

    def fetch(groups)
      groups.each do |group|
        group.fetch do |_partition, bulk|
          break if bulk.empty?
          bulk.each { |m| Karafka::Router.new(group.topic, m.value) }
        end
        group.close
      end
    end

    def consumer_groups
      groups = []
      options.map(&:group).uniq.each do |group|
        topic = options.detect{ |opt| opt.group == group }.topic
        groups << new_consumer_group(group, topic)
      end
      groups
    end

    def new_consumer_group(group, topic)
      Poseidon::ConsumerGroup.new(
        group,
        @brokers,
        @zookeeper_hosts,
        topic,
        socket_timeout_ms: 50_000 # Karafka.config.socket_timeout_ms
      )
    end
    #
    def klasses_options
      Karafka::BaseController.descendants.map do |klass|
        OpenStruct.new(topic: klass.topic, group: klass.group)
      end
    end
  end
end
