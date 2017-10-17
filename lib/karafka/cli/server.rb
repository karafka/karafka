# frozen_string_literal: true

module Karafka
  # Karafka framework Cli
  class Cli < Thor
    # Server Karafka Cli action
    class Server < Base
      desc 'Start the Karafka server (short-cut alias: "s")'
      option aliases: 's'
      option :daemon, default: false, type: :boolean, aliases: :d
      option :pid, default: 'tmp/pids/karafka', type: :string, aliases: :p
      option :consumer_groups, type: :array, default: nil, aliases: :g

      # Start the Karafka server
      def call
        validate!

        puts 'Starting Karafka server'
        cli.info

        if cli.options[:daemon]
          FileUtils.mkdir_p File.dirname(cli.options[:pid])
          # For some reason Celluloid spins threads that break forking
          # Threads are not shutdown immediately so deamonization will stale until
          # those threads are killed by Celluloid manager (via timeout)
          # There's nothing initialized here yet, so instead we shutdown celluloid
          # and run it again when we need (after fork)
          Celluloid.shutdown
          daemonize
          Celluloid.boot
        end

        # We assign active topics on a server level, as only server is expected to listen on
        # part of the topics
        Karafka::Server.consumer_groups = cli.options[:consumer_groups]

        # Remove pidfile on shutdown, just before the server instance is going to be GCed
        ObjectSpace.define_finalizer(self, proc { send(:clean) })

        # After we fork, we can boot celluloid again
        Karafka::Server.run
      end

      private

      # Checks the server cli configuration
      # options validations in terms of app setup (topics, pid existence, etc)
      def validate!
        result = Schemas::ServerCliOptions.call(cli.options)
        return if result.success?
        raise Errors::InvalidConfiguration, result.errors
      end

      # Detaches current process into background and writes its pidfile
      def daemonize
        ::Process.daemon(true)
        File.open(
          cli.options[:pid],
          'w'
        ) { |file| file.write(::Process.pid) }
      end

      # Removes a pidfile (if exist)
      def clean
        FileUtils.rm_f(cli.options[:pid]) if cli.options[:pid]
      end
    end
  end
end
