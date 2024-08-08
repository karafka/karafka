# frozen_string_literal: true

module Karafka
  module Swarm
    # Represents a single forked process node in a swarm
    # Provides simple API to control forks and check their status
    #
    # @note Some of this APIs are for parent process only
    #
    # @note Keep in mind this can be used in both forks and supervisor and has a slightly different
    #   role in each. In case of the supervisor it is used to get information about the child and
    #   make certain requests to it. In case of child, it is used to provide zombie-fencing and
    #   report liveness
    class Node
      include Helpers::ConfigImporter.new(
        monitor: %i[monitor],
        config: %i[itself],
        kafka: %i[kafka],
        swarm: %i[swarm],
        process: %i[process],
        liveness_listener: %i[internal swarm liveness_listener]
      )

      # @return [Integer] id of the node. Useful for client.group.id assignment
      attr_reader :id

      # @return [Integer] pid of the node
      attr_reader :pid

      # @param id [Integer] number of the fork. Used for uniqueness setup for group client ids and
      #   other stuff where we need to know a unique reference of the fork in regards to the rest
      #   of them.
      # @param parent_pid [Integer] parent pid for zombie fencing
      def initialize(id, parent_pid)
        @id = id
        @parent_pidfd = Pidfd.new(parent_pid)
      end

      # Starts a new fork and:
      #   - stores pid and parent reference
      #   - makes sure reader pipe is closed
      #   - sets up liveness listener
      #   - recreates producer and web producer
      # @note Parent API
      def start
        @reader, @writer = IO.pipe

        # :nocov:
        @pid = ::Process.fork do
          # Close the old producer so it is not a subject to GC
          # While it was not opened in the parent, without explicit closing, there still could be
          # an attempt to close it when finalized, meaning it would be kept in memory.
          config.producer.close

          # Supervisor producer is closed, hence we need a new one here
          config.producer = ::WaterDrop::Producer.new do |p_config|
            p_config.kafka = Setup::AttributesMap.producer(kafka.dup)
            p_config.logger = config.logger
          end

          @pid = ::Process.pid
          @reader.close

          # Indicate we are alive right after start
          healthy

          swarm.node = self
          monitor.subscribe(liveness_listener)
          monitor.instrument('swarm.node.after_fork', caller: self)

          Karafka::Process.tags.add(:execution_mode, 'mode:swarm')
          Server.execution_mode = :swarm
          Server.run

          @writer.close
        end
        # :nocov:

        @writer.close
        @pidfd = Pidfd.new(@pid)
      end

      # Indicates that this node is doing well
      # @note Child API
      def healthy
        write('0')
      end

      # Indicates, that this node has failed
      # @param reason_code [Integer, String] numeric code we want to use to indicate that we are
      #   not healthy. Anything bigger than 0 will be considered not healthy. Useful it we want to
      #   have complex health-checking with reporting.
      # @note Child API
      # @note We convert this to string to normalize the API
      def unhealthy(reason_code = '1')
        write(reason_code.to_s)
      end

      # @return [Integer] This returns following status code depending on the data:
      #   - -1 if node did not report anything new
      #   - 0 if all good,
      #   - positive number if there was a problem (indicates error code)
      #
      # @note Parent API
      # @note If there were few issues reported, it will pick the one with highest number
      def status
        result = read

        return -1 if result.nil?
        return -1 if result == false

        result.split("\n").map(&:to_i).max
      end

      # @return [Boolean] true if node is alive or false if died
      # @note Parent API
      # @note Keep in mind that the fact that process is alive does not mean it is healthy
      def alive?
        @pidfd.alive?
      end

      # @return [Boolean] true if node is orphaned or false otherwise. Used for orphans detection.
      # @note Child API
      def orphaned?
        !@parent_pidfd.alive?
      end

      # Sends sigterm to the node
      # @note Parent API
      def stop
        signal('TERM')
      end

      # Sends sigtstp to the node
      # @note Parent API
      def quiet
        signal('TSTP')
      end

      # Terminates node
      # @note Parent API
      def terminate
        signal('KILL')
      end

      # Sends provided signal to the node
      # @param signal [String]
      def signal(signal)
        @pidfd.signal(signal)
      end

      # Removes the dead process from the processes table
      def cleanup
        @pidfd.cleanup
      end

      private

      # Reads in a non-blocking way provided content
      # @return [String, false] Content from the pipe or false if nothing or something went wrong
      # @note Parent API
      def read
        @reader.read_nonblock(1024)
      rescue IO::WaitReadable, Errno::EPIPE, IOError
        false
      end

      # Writes in a non-blocking way provided content into the pipe
      # @param content [Integer, String] anything we want to write to the parent
      # @return [Boolean] true if ok, otherwise false
      # @note Child API
      def write(content)
        @writer.write_nonblock "#{content}\n"

        true
      rescue IO::WaitWritable, Errno::EPIPE, IOError
        false
      end
    end
  end
end
