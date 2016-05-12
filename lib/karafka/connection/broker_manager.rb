# frozen_string_literal: true
module Karafka
  module Connection
    # Broker manager allows us to fetch Kafka brokers details from Zookeeper
    # Fetching them from Zookeeper instead of forcing user to set it, provides more flexibility,
    # since we can rediscover them on demand.
    # Kafka brokers can change during the runtime of Kafka process (some will day, new will start)
    # and if that happens we can ask Zookeeper to provide us with a new list of brokers to which
    # we can connect
    class BrokerManager
      # Path at Zookeeper under which brokers details are being stored
      BROKERS_PATH = '/brokers/ids'

      # @return [Array<Karafka::Connection::Broker>] Array with details about all the brokers
      # @example Create new manager and get details about the brokers
      #   Karafka::Connection::BrokerManager.new.all #> [#<Broker jmx_port=7203, timestamp="1...>]
      def all
        ids.map do |id|
          Broker.new(find(id))
        end
      end

      private

      # @param id [String] id of Kafka broker
      # @return [::Karafka::Connection::Broker] single Kafka broker details
      def find(id)
        zk.get("#{BROKERS_PATH}/#{id}").first
      end

      # @return [Array<String>] ids of all the brokers
      # @example
      #   ids #=> ['0', '2', '3']
      def ids
        zk.children(BROKERS_PATH)
      end

      # @return [::ZK] Zookeeper high level client
      def zk
        @zk ||= ::ZK.new(
          ::Karafka::App.config.zookeeper.hosts.join(',')
        )
      end
    end
  end
end
