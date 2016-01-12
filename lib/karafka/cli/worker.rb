module Karafka
  # Karafka framework Cli
  class Cli
    desc 'worker', 'Start the Karafka Sidekiq worker (short-cut alias: "w")'
    method_option :worker, aliases: 'w'
    # Start the Karafka Sidekiq worker
    def worker
      puts 'Starting Karafka worker'
      info

      config_file = Karafka::App.root.join('config/sidekiq.yml')
      cmd = "bundle exec sidekiq -e #{Karafka.env} -r #{Karafka.boot_file} -C #{config_file}"
      puts(cmd)
      exec(cmd)
    end
  end
end
