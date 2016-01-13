module Karafka
  # Karafka framework Cli
  class Cli
    desc 'worker', 'Start the Karafka Sidekiq worker (short-cut alias: "w")'
    # Start the Karafka Sidekiq worker
    # @param params [Array<String>] additional params that will be passed to sidekiq, that way we
    #   can override any default Karafka settings
    def worker(*params)
      puts 'Starting Karafka worker'
      config = "-C #{Karafka::App.root.join('config/sidekiq.yml')}"
      req = "-r #{Karafka.boot_file}"
      env = "-e #{Karafka.env}"

      info

      cmd = "bundle exec sidekiq #{env} #{req} #{config} #{params.join(' ')}"
      puts(cmd)
      exec(cmd)
    end
  end
end
