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
          daemonize
        end

        # We assign active topics on a server level, as only server is expected to listen on
        # part of the topics
        Karafka::Server.consumer_groups = cli.options[:consumer_groups]

        # Remove pidfile on stop, just before the server instance is going to be GCed
        # We want to delay the moment in which the pidfile is removed as much as we can,
        # so instead of removing it after the server stops running, we rely on the gc moment
        # when this object gets removed (it is a bit later), so it is closer to the actual
        # system process end. We do that, so monitoring and deployment tools that rely on pids
        # won't alarm or start new system process up until the current one is finished
        ObjectSpace.define_finalizer(self, proc { send(:clean) })

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
