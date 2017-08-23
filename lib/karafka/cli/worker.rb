# frozen_string_literal: true

module Karafka
  # Karafka framework Cli
  class Cli < Thor
    # Worker Karafka Cli action
    class Worker < Base
      desc 'Start the Karafka Sidekiq worker (short-cut alias: "w")'
      option aliases: 'w'

      # Start the Karafka Sidekiq worker
      # @param params [Array<String>] additional params that will be passed to sidekiq, that way we
      #   can override any default Karafka settings
      def call(*params)
        puts 'Starting Karafka worker'
        config = "-C #{Karafka::App.root.join('config/sidekiq.yml')}"
        req = "-r #{Karafka.boot_file}"
        env = "-e #{Karafka.env}"

        cli.info

        cmd = "bundle exec sidekiq #{env} #{req} #{config} #{params.join(' ')}"
        puts(cmd)
        exec(cmd)
      end
    end
  end
end
