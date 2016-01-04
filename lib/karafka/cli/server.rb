module Karafka
  # Karafka framework Cli
  class Cli
    desc 'server', 'Start the Karafka server (short-cut alias: "s")'
    method_option :server, aliases: 's'
    def server
      puts('Starting Karafka framework')
      puts("Environment: #{Karafka.env}")
      puts("Kafka hosts: #{Karafka::App.config.kafka_hosts}")
      puts("Zookeeper hosts: #{Karafka::App.config.zookeeper_hosts}")
      Karafka::App.run
    end
  end
end
