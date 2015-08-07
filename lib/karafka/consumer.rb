require 'karafka/router'
# Main module namespace
module Karafka
  # Class that receive events
  class Consumer
    attr_reader :options

    class DuplicatedGroupError < StandardError; end
    class DuplicatedTopicError < StandardError; end

    def initialize(brokers, zookeeper_hosts)
      @brokers = brokers
      @zookeeper_hosts = zookeeper_hosts
      @options = klasses_options
    end

    # Receive the messages
    def receive
      validate
      loop { fetch }
    end

    private

    def fetch
      consumer_groups.each do |group|
        group.fetch do |_partition, bulk|
          break if bulk.empty?
          bulk.each { |m| Karafka::Router.new(group.topic, m.value).forward }
        end
        group.close
      end
    end

    def consumer_groups
      groups = []
      options.map(&:group).each do |group|
        topic = options.detect { |opt| opt.group == group }.topic
        groups << new_consumer_group(group, topic)
      end
      groups
    end

    def new_consumer_group(group, topic)
      Poseidon::ConsumerGroup.new(
        group,
        @brokers,
        @zookeeper_hosts,
        topic.to_s,
        socket_timeout_ms: 50_000 # Karafka.config.socket_timeout_ms
      )
    end
    #
    def klasses_options
      Karafka::BaseController.descendants.map do |klass|
        OpenStruct.new(topic: klass.topic, group: klass.group)
      end
    end

    def validate
      %i(group topic).each do |field|
        fields = options.map(&field).map(&:to_s)
        error = Object.const_get("Karafka::Consumer::Duplicated#{field.capitalize}Error")
        fail error if fields.uniq != fields
      end
    end
  end
end
