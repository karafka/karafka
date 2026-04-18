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
        @parent_pid = parent_pid
        @mutex = Mutex.new
        @alive = nil
      end

      # Starts a new fork and:
      #   - stores pid and parent reference
      #   - makes sure reader pipe is closed
      #   - sets up liveness listener
      #   - recreates producer and web producer
      # @note Parent API
      def start
        # Close the previous reader pipe if it exists to prevent FD leaks on node restarts.
        # Without this, each restart orphans the old reader pipe in the supervisor, and forked
        # children inherit all accumulated leaked FDs.
        begin
          @reader&.close
        rescue IOError
          nil
        end
        @reader, @writer = IO.pipe
        # Reset alive status when starting/restarting a node
        # nil means unknown status - will check with waitpid
        @mutex.synchronize { @alive = nil }

        # :nocov:
        @pid = ::Process.fork do
          # Close the old producer so it is not a subject to GC
          # While it was not opened in the parent, without explicit closing, there still could be
          # an attempt to close it when finalized, meaning it would be kept in memory.
          config.producer.close

          old_producer = config.producer
          config.producer = ProducerReplacer.new.call(old_producer, kafka, config.logger)

          @pid = ::Process.pid
          @reader.close

          # Certain features need to be reconfigured / reinitialized after fork in Pro
          Pro::Loader.post_fork(config, old_producer) if Karafka.pro?

          # Indicate we are alive right after start
          healthy

          swarm.node = self
          monitor.subscribe(liveness_listener)
          monitor.instrument("swarm.node.after_fork", caller: self)

          Karafka::Process.tags.add(:execution_mode, "mode:swarm")
          Karafka::Process.tags.add(:swarm_nodeid, "node:#{@id}")

          # DEBUG: Monkey-patch NativeKafka#close to log timing
          original_nk_close = Rdkafka::NativeKafka.instance_method(:close)
          Rdkafka::NativeKafka.define_method(:close) do |object_id = nil, &block|
            caller_loc = caller_locations(1, 3).map { |l| "#{l.path}:#{l.lineno}:#{l.label}" }.join(" <- ")
            name_str = begin
                          @inner ? Rdkafka::Bindings.rd_kafka_name(@inner) : "nil"
                        rescue StandardError
                          "unknown"
                        end
            $stderr.puts "[SWARM_DEBUG] NativeKafka#close ENTER name=#{name_str} " \
              "closed=#{closed?} ops_in_progress=#{@operations_in_progress} " \
              "caller=#{caller_loc} wall=#{Time.now.strftime('%H:%M:%S.%L')}"
            $stderr.flush
            t0 = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC, :float_millisecond)
            result = original_nk_close.bind_call(self, object_id, &block)
            elapsed = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC, :float_millisecond) - t0
            $stderr.puts "[SWARM_DEBUG] NativeKafka#close EXIT name=#{name_str} " \
              "took=#{elapsed.round(1)}ms wall=#{Time.now.strftime('%H:%M:%S.%L')}"
            $stderr.flush
            result
          end

          # DEBUG: earliest at_exit (registered first, runs LAST)
          at_exit do
            $stderr.puts "[SWARM_DEBUG] node #{@id} pid=#{::Process.pid} FINAL_AT_EXIT " \
              "(last registered handler done) wall=#{Time.now.strftime('%H:%M:%S.%L')}"
            $stderr.puts "[SWARM_DEBUG] Thread.list at FINAL_AT_EXIT:"
            Thread.list.each do |t|
              bt = t.backtrace
              $stderr.puts "  thread=#{t.object_id} name=#{t.name.inspect} " \
                "status=#{t.status} alive=#{t.alive?}"
              if bt && !bt.empty?
                bt.first(5).each { |frame| $stderr.puts "    #{frame}" }
              end
            end
            $stderr.flush
          end

          # DEBUG: later at_exit (registered second, runs FIRST) — dump state
          at_exit do
            $stderr.puts "[SWARM_DEBUG] node #{@id} pid=#{::Process.pid} AT_EXIT running " \
              "wall=#{Time.now.strftime('%H:%M:%S.%L')}"
            # Dump all live threads with backtraces
            $stderr.puts "[SWARM_DEBUG] Thread.list at AT_EXIT (#{Thread.list.size} threads):"
            Thread.list.each do |t|
              bt = t.backtrace
              $stderr.puts "  thread=#{t.object_id} name=#{t.name.inspect} " \
                "status=#{t.status} alive=#{t.alive?}"
              if bt && !bt.empty?
                bt.first(8).each { |frame| $stderr.puts "    #{frame}" }
              end
            end
            # Count live rdkafka/waterdrop objects
            nk_count = 0
            ObjectSpace.each_object(Rdkafka::NativeKafka) do |nk|
              nk_count += 1
              inner_nil = begin
                            nk.instance_variable_get(:@inner).nil?
                          rescue StandardError
                            "err"
                          end
              closing = begin
                          nk.instance_variable_get(:@closing)
                        rescue StandardError
                          "err"
                        end
              $stderr.puts "  NativeKafka obj=#{nk.object_id} inner_nil=#{inner_nil} " \
                "closing=#{closing} closed=#{nk.closed?}"
            end
            $stderr.puts "[SWARM_DEBUG] live NativeKafka objects: #{nk_count}"
            wp_count = 0
            ObjectSpace.each_object(WaterDrop::Producer) do |wp|
              wp_count += 1
              $stderr.puts "  WaterDrop::Producer obj=#{wp.object_id} status=#{wp.status}"
            end
            $stderr.puts "[SWARM_DEBUG] live WaterDrop::Producer objects: #{wp_count}"
            $stderr.flush
          end

          Server.execution_mode.swarm!
          Server.run

          $stderr.puts "[SWARM_DEBUG] node #{@id} pid=#{::Process.pid} Server.run returned " \
            "wall=#{Time.now.strftime('%H:%M:%S.%L')}"
          $stderr.flush
          @writer.close
          $stderr.puts "[SWARM_DEBUG] node #{@id} pid=#{::Process.pid} fork block ending " \
            "wall=#{Time.now.strftime('%H:%M:%S.%L')}"
          $stderr.flush
        end
        # :nocov:

        @writer.close
      end

      # Indicates that this node is doing well
      # @note Child API
      def healthy
        write("0")
      end

      # Indicates, that this node has failed
      # @param reason_code [Integer, String] numeric code we want to use to indicate that we are
      #   not healthy. Anything bigger than 0 will be considered not healthy. Useful it we want to
      #   have complex health-checking with reporting.
      # @note Child API
      # @note We convert this to string to normalize the API
      def unhealthy(reason_code = "1")
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
        # Don't try to waitpid on ourselves - just check if process exists
        return true if @pid == ::Process.pid

        @mutex.synchronize do
          # Return cached result if we've already determined the process is dead
          if @alive == false
            # DEBUG: only log first time we return cached false
            unless @_debug_cached_logged
              $stderr.puts "[SWARM_DEBUG] node #{@id} pid=#{@pid} alive? returning cached false"
              $stderr.flush
              @_debug_cached_logged = true
            end
            return false
          end

          before_waitpid = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC, :float_millisecond)

          begin
            # Try to reap the process without blocking. If it returns the pid,
            # the process has exited (zombie). If it returns nil, still running.
            result = ::Process.waitpid(@pid, ::Process::WNOHANG)
            after_waitpid = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC, :float_millisecond)
            waitpid_ms = after_waitpid - before_waitpid

            if result
              # Process has exited and we've reaped it
              @alive = false
              $stderr.puts "[SWARM_DEBUG] node #{@id} pid=#{@pid} REAPED by waitpid " \
                "(result=#{result}, took=#{waitpid_ms.round(2)}ms) wall=#{Time.now.strftime('%H:%M:%S.%L')}"
              $stderr.flush
              false
            else
              # DEBUG: log slow waitpid or periodic status
              if waitpid_ms > 1.0
                $stderr.puts "[SWARM_DEBUG] node #{@id} pid=#{@pid} waitpid(WNOHANG) returned nil " \
                  "but took #{waitpid_ms.round(2)}ms (SLOW)"
                $stderr.flush
              end
              # Process is still running
              true
            end
          rescue Errno::ECHILD
            after_waitpid = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC, :float_millisecond)
            $stderr.puts "[SWARM_DEBUG] node #{@id} pid=#{@pid} got ECHILD " \
              "(took=#{(after_waitpid - before_waitpid).round(2)}ms) — already reaped elsewhere"
            $stderr.flush
            # Process doesn't exist or already reaped
            @alive = false
            false
          rescue Errno::ESRCH
            after_waitpid = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC, :float_millisecond)
            $stderr.puts "[SWARM_DEBUG] node #{@id} pid=#{@pid} got ESRCH " \
              "(took=#{(after_waitpid - before_waitpid).round(2)}ms) — process doesn't exist"
            $stderr.flush
            # Process doesn't exist
            @alive = false
            false
          end
        end
      end

      # @return [Boolean] true if node is orphaned or false otherwise. Used for orphans detection.
      # @note Child API
      def orphaned?
        ::Process.ppid != @parent_pid
      end

      # Sends sigterm to the node
      # @note Parent API
      def stop
        signal("TERM")
      end

      # Sends sigtstp to the node
      # @note Parent API
      def quiet
        signal("TSTP")
      end

      # Terminates node
      # @note Parent API
      def terminate
        signal("KILL")
      end

      # Sends provided signal to the node
      # @param signal [String]
      # @return [Boolean] true if signal was sent, false if process doesn't exist
      def signal(signal)
        ::Process.kill(signal, @pid)
        true
      rescue Errno::ESRCH
        # Process doesn't exist
        false
      end

      # Removes the dead process from the processes table
      # @return [Boolean] true if process was reaped, false if still running or already reaped
      def cleanup
        @mutex.synchronize do
          # If we've already marked it as dead (reaped in alive?), nothing to do
          return false if @alive == false

          begin
            # WNOHANG means don't block if process hasn't exited yet
            result = ::Process.waitpid(@pid, ::Process::WNOHANG)

            if result
              # Process exited and was reaped
              @alive = false
              true
            else
              # Process is still running
              false
            end
          rescue Errno::ECHILD
            # Process already reaped or doesn't exist, which is fine
            @alive = false
            false
          end
        end
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
