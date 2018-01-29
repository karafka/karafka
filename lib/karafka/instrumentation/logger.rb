# frozen_string_literal: true

module Karafka
  module Instrumentation
    # Default logger for Event Delegator
    # @note It uses ::Logger features - providing basic logging
    class Logger < ::Logger
      include Singleton

      # Map containing information about log level for given environment
      ENV_MAP = {
        'production' => ::Logger::ERROR,
        'test' => ::Logger::ERROR,
        'development' => ::Logger::INFO,
        'debug' => ::Logger::DEBUG,
        'default' => ::Logger::INFO
      }.freeze

      # Creates a new instance of logger ensuring that it has a place to write to
      def initialize(*_args)
        ensure_dir_exists
        super(target)
        self.level = ENV_MAP[Karafka.env] || ENV_MAP['default']
      end

      private

      # @return [Karafka::Helpers::MultiDelegator] multi delegator instance
      #   to which we will be writtng logs
      # We use this approach to log stuff to file and to the STDOUT at the same time
      def target
        Karafka::Helpers::MultiDelegator
          .delegate(:write, :close)
          .to(STDOUT, file)
      end

      # Makes sure the log directory exists
      def ensure_dir_exists
        dir = File.dirname(log_path)
        FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
      end

      # @return [Pathname] Path to a file to which we should log
      def log_path
        @log_path ||= Karafka::App.root.join("log/#{Karafka.env}.log")
      end

      # @return [File] file to which we want to write our logs
      # @note File is being opened in append mode ('a')
      def file
        @file ||= File.open(log_path, 'a')
      end
    end
  end
end
