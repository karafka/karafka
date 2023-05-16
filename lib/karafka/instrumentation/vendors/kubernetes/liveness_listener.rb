# frozen_string_literal: true

require 'socket'

module Karafka
  module Instrumentation
    module Vendors
      # Namespace for instrumentation related with Kubernetes
      module Kubernetes
        # Kubernetes HTTP listener that does not only reply when process is not fully hanging, but
        # also allows to define max time of processing and looping.
        #
        # Processes like Karafka server can hang while still being reachable. For example, in case
        # something would hang inside of the user code, Karafka could stop polling and no new
        # data would be processed, but process itself would still be active. This listener allows
        # for defining of a ttl that gets bumped on each poll loop and before and after processing
        # of a given messages batch.
        class LivenessListener
          include ::Karafka::Core::Helpers::Time

          # @param hostname [String, nil] hostname or nil to bind on all
          # @param port [Integer] TCP port on which we want to run our HTTP status server
          # @param consuming_ttl [Integer] time in ms after which we consider consumption hanging.
          #   It allows us to define max consumption time after which k8s should consider given
          #   process as hanging
          # @param polling_ttl [Integer] max time in ms for polling. If polling (any) does not
          #   happen that often, process should be considered dead.
          # @note The default TTL matches the default `max.poll.interval.ms`
          def initialize(
            hostname: nil,
            port: 3000,
            consuming_ttl: 5 * 60 * 1_000,
            polling_ttl: 5 * 60 * 1_000
          )
            @server = TCPServer.new(*[hostname, port].compact)
            @polling_ttl = polling_ttl
            @consuming_ttl = consuming_ttl

            polling_tick
            consuming_tick

            Thread.new do
              loop do
                break unless respond
              end
            end
          end

          # Tick on each fetch
          # @param _event [Karafka::Core::Monitoring::Event]
          def on_connection_listener_fetch_loop(_event)
            polling_tick
          end

          # Tick on starting work
          # @param _event [Karafka::Core::Monitoring::Event]
          def on_consumer_consume(_event)
            consuming_tick
          end

          # Tick on finished work
          # @param _event [Karafka::Core::Monitoring::Event]
          def on_consumer_consumed(_event)
            consuming_tick
          end

          # Stop the http server when we stop the process
          # @param _event [Karafka::Core::Monitoring::Event]
          def on_app_stopped(_event)
            @server.close
          end

          private

          # Update the polling tick time
          def polling_tick
            @polling_tick = monotonic_now
          end

          # Update the processing tick time
          def consuming_tick
            @consuming_tick = monotonic_now
          end

          # Responds to a HTTP request with the process liveness status
          #
          # @param client [TCPSocket] socket for given http request
          def respond
            client = server.accept
            client.gets
            client.print "HTTP/1.1 #{status}\r\n"
            client.close

            true
          rescue Errno::ECONNRESET, Errno::EPIPE, IOError
            !@server.closed?
          end

          # Did we exceed the ttl
          # @return [String] "ok" or "timeout"
          def status
            return '500' if (monotonic_now - @polling_tick) > @polling_ttl
            return '500' if (monotonic_now - @consuming_tick) > @consuming_ttl

            '204'
          end
        end
      end
    end
  end
end
