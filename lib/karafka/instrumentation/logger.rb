# frozen_string_literal: true

module Karafka
  module Instrumentation
    # Default logger for Event Delegator
    # @note It uses Logger features - providing basic logging
    class Logger < ::Logger
      # Wraps a log file target and opens it lazily, only on the first write.
      #
      # This lets Karafka boot without touching the filesystem and keeps logging working (to
      # stdout via the surrounding multi-delegator) even when the log file cannot be created or
      # written, for example on a read-only filesystem.
      class LazyFile
        # @param open_file [Proc] callable that opens and returns the underlying file or returns
        #   `nil` when it cannot be opened (for example on a read-only filesystem)
        def initialize(&open_file)
          @open_file = open_file
        end

        # Writes a message to the underlying file when one is available.
        #
        # Both the lazy open and the write itself are guarded, so a read-only or otherwise
        # unwritable filesystem never crashes logging - the message is simply not written to the
        # file (it is still written to stdout by the surrounding multi-delegator).
        #
        # @param message [String] message to write
        # @return [Integer, nil] number of bytes written or `nil` when there is no writable file
        def write(message)
          file&.write(message)
        rescue Errno::EACCES, Errno::EROFS
          nil
        end

        # Closes the underlying file if it was ever opened.
        # @return [nil]
        def close
          @file&.close

          nil
        rescue Errno::EACCES, Errno::EROFS
          nil
        end

        private

        # @return [File, nil] the underlying file or `nil` when it could not be opened
        # @note The outcome (including a `nil` failure) is memoized, so on a read-only filesystem
        #   we do not keep retrying to open the file on every single write.
        def file
          return @file if defined?(@file)

          @file = @open_file.call
        end
      end

      private_constant :LazyFile

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
        super(target)
        self.level = ENV_MAP[Karafka.env] || ENV_MAP["default"]
      end

      private

      # @return [Karafka::Helpers::MultiDelegator] multi delegator instance
      #   to which we will be writing logs
      # We use this approach to log stuff to file and to the $stdout at the same time
      def target
        Karafka::Helpers::MultiDelegator
          .delegate(:write, :close)
          .to($stdout, LazyFile.new { file })
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
