module Karafka
  # Karafka framework Cli
  class Cli
    desc 'worker', 'Start the Karafka Sidekiq worker (short-cut alias: "w")'
    method_option :worker, aliases: 'w'
    def worker
      require_file = Karafka::App.root.join('app.rb')
      config_file = Karafka::App.root.join('config/sidekiq.yml')

      puts('Starting Karafka Sidekiq')
      puts("Environment: #{Karafka.env}")
      puts("Kafka hosts: #{Karafka::App.config.kafka_hosts}")
      puts("Zookeeper hosts: #{Karafka::App.config.zookeeper_hosts}")
      cmd = "bundle exec sidekiq -e #{Karafka.env} -r #{require_file} -C #{config_file}"
      puts(cmd)
      exec(cmd)
    end
  end
end
