# frozen_string_literal: true

module Karafka
  module Instrumentation
    # Default logger for Event Delegator
    # @note It uses Logger features - providing basic logging
    class Logger < ::Logger
      # Map containing information about log level for given environment
      ENV_MAP = {
        "production" => Logger::ERROR,
        "test" => Logger::ERROR,
        "development" => Logger::INFO,
        "debug" => Logger::DEBUG,
        "default" => Logger::INFO
      }.freeze

      private_constant :ENV_MAP

      # Creates a new instance of logger ensuring that it has a place to write to
      # @param _args Any arguments that we don't care about but that are needed in order to
      #   make this logger compatible with the default Ruby one
      def initialize(*_args)
        @stdout = $stdout
        @log_file = LazyFile.new { file }
        super(target)
        self.level = ENV_MAP[Karafka.env] || ENV_MAP["default"]
      end

      # Flushes buffered logs to the log file and to stdout
      # @note Used before `Kernel.exit!` (forceful shutdown), which skips the IO finalizers. The
      #   file goes first and each target has its own rescue, so a broken stdout (closed, broken
      #   pipe) does not prevent the file flush.
      def flush
        [@log_file, @stdout].each do |log_target|
          log_target.flush
        rescue IOError, SystemCallError
          nil
        end

        nil
      end

      private

      # @return [Karafka::Helpers::MultiDelegator] multi delegator instance
      #   to which we will be writing logs
      # We use this approach to log stuff to file and to the $stdout at the same time
      def target
        Karafka::Helpers::MultiDelegator
          .delegate(:write, :close)
          .to(@stdout, @log_file)
      end

      # @return [Pathname] Path to a file to which we should log
      def log_path
        @log_path ||= Karafka::App.root.join("log/#{Karafka.env}.log")
      end

      # @return [File] file to which we want to write our logs
      # @note File is being opened in append mode ('a')
      def file
        FileUtils.mkdir_p(File.dirname(log_path))

        @file ||= File.open(log_path, "a")
      rescue Errno::EACCES, Errno::EROFS
        nil
      end
    end
  end
end
