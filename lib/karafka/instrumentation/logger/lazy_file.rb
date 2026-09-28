# frozen_string_literal: true

module Karafka
  module Instrumentation
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
    end
  end
end
