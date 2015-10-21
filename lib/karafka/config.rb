module Karafka
  # Configurator for setting up delivery details
  class Config
    class << self
      attr_accessor :config
    end
    # Available settings
    # option zookeeper_hosts [Array] zookeeper hosts with ports where zookeeper servers are run
    # option kafka_hosts [Array] kafka hosts with ports where kafka servers are run
    # option redis_url [String] place where Redis is ('redis://redis.example.com:7372/1')
    # option redis_namespace [String] redis namespace
    # option worker_timeout [Integer] how many seconds should we proceed stuff at Sidekiq
    # option concurrency [Integer] how many threads that listen to incoming connections can we have
    # option name [String] current app name - used to provide default Kafka groups namespaces
    SETTINGS = %i(
      zookeeper_hosts
      kafka_hosts
      redis_url
      redis_namespace
      worker_timeout
      concurrency
      name
    )

    SETTINGS.each do |attr_name|
      attr_accessor attr_name
    end

    # Configurating method
    def self.setup(&block)
      self.config ||= new

      block.call(config)
      config.freeze
    end
  end
end
