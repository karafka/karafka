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
      loop do
        fetch
        sleep 1
      end
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

    def new_consumer_group(group_name, topic_name)
      Poseidon::ConsumerGroup.new(
        group_name,
        @brokers,
        @zookeeper_hosts,
        topic_name.to_s
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
