module Karafka
  # Karafka framework Cli
  class Cli
    # Server Karafka Cli action
    class Server < Base
      desc 'Start the Karafka server (short-cut alias: "s")'
      option aliases: 's'
      option :daemon, default: false, type: :boolean, aliases: :d
      option :pid, default: 'tmp/pids/karafka.pid', type: :string, aliases: :p

      # Start the Karafka server
      def call
        puts 'Starting Karafka framework server'
        cli.info

        prepare if cli.options[:pid]
        daemonize if cli.options[:daemon]
        Karafka::Server.run
      ensure
        clean if cli.options[:pid]
      end

      private

      # Prepare (if not exists) directory for a pidfile and check if there is no running karafka
      # instance already (and raise error if so)
      def prepare
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
