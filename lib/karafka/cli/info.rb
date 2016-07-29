module Karafka
  # Karafka framework Cli
  class Cli
    # Info Karafka Cli action
    class Info < Base
      self.desc = 'Print configuration details and other options of your application'

      # Print configuration details and other options of your application
      def call
        config = Karafka::App.config

        info = [
          "Karafka framework version: #{Karafka::VERSION}",
          "Application name: #{config.name}",
          "Max number of threads: #{config.max_concurrency}",
          "Boot file: #{Karafka.boot_file}",
          "Environment: #{Karafka.env}",
          "Zookeeper hosts: #{config.zookeeper.hosts}",
          "Zookeeper chroot: #{config.zookeeper.chroot}",
          "Zookeeper brokers_path: #{config.zookeeper.brokers_path}",
          "Kafka hosts: #{config.kafka.hosts}",
          "Redis: #{config.redis.to_h}",
          "Wait timeout: #{config.wait_timeout}"
        ]

        puts(info.join("\n"))
      end
    end
  end
end
