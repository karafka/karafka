module Karafka
  # Karafka framework Cli
  class Cli
    # Server Karafka Cli action
    class Server < Base
      desc 'Start the Karafka server (short-cut alias: "s")'
      option aliases: 's'
      option :daemon, default: false, type: :boolean, aliases: :d
      option :pid, default: 'tmp/pids/karafka', type: :string, aliases: :p

      # Start the Karafka server
      def call
        puts 'Starting Karafka server'
        cli.info

        if cli.options[:daemon]
          # For some reason Celluloid spins threads that break forking
          # Threads are not shutdown immediately so deamonization will stale until
          # those threads are killed by Celluloid manager (via timeout)
          # There's nothing initialized here yet, so instead we shutdown celluloid
          # and run it again when we need (after fork)
          Celluloid.shutdown
          validate!
          daemonize
          Celluloid.boot
        end

        # Remove pidfile on shutdown
        ObjectSpace.define_finalizer('string', proc { send(:clean) })

        # After we fork, we can boot celluloid again
        Karafka::Server.run
      end

      private

      # Prepare (if not exists) directory for a pidfile and check if there is no running karafka
      # instance already (and raise error if so)
      def validate!
        FileUtils.mkdir_p File.dirname(cli.options[:pid])
        raise "#{cli.options[:pid]} already exists" if File.exist?(cli.options[:pid])
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
        FileUtils.rm_f(cli.options[:pid])
      end
    end
  end
end
