module Karafka
  module Setup
    # Class containing defaults for configuration - if a given option is not specified, it will
    # use one hidden under a proper method from this class
    class Defaults
      class << self
        # @return [Array<String>] all Kafka hosts (with ports)
        # @note If hosts were not provided Karafka will ask Zookeeper for Kafka brokers.
        #   This is the default behaviour because it allows us to autodiscover new brokers
        #   and detect changes. It will create a bigger load on Zookeeeper since on each failure
        #   it will reobtain brokers.
        #   This is the reason why we don't use ||= syntax - it would assign and store brokers that
        #   might change during the runtime
        # @example
        #   kafka_hosts #=> ['172.17.0.2:9092', '172.17.0.4:9092']
        def kafka_hosts
          ::Karafka::Connection::BrokerManager.new.all.map(&:host)
        end

        # @return [::Karafka::Monitor] default monitor instance
        def monitor
          ::Karafka::Monitor.instance
        end

        # @return [::Karafka::Logger] default Karafka logger
        def logger
          ::Karafka::Logger.build
        end
      end
    end
  end
end
