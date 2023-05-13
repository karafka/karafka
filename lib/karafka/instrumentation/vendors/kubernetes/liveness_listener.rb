# frozen_string_literal: true

require 'socket'

module Karafka
  module Instrumentation
    module Vendors
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
          # @param ttl [Integer] time in ms after which we consider our process no longer ok.
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
                break unless respond(@server)
              end
            end
          end

          # Tick on each fetch
          def on_connection_listener_fetch_loop(_)
            polling_tick
          end

          # Tick on starting work
          def on_consumer_consume(_)
            consuming_tick
          end

          # Tick on finished work
          def on_consumer_consumed(_)
            consuming_tick
          end

          # Stop the http server when we stop the process
          def on_app_stopped(_)
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
          def respond(client)
            client = @server.accept
            client.gets
            client.print "HTTP/1.1 #{status}\r\n"
            client.close

            true
          rescue Errno::ECONNRESET, Errno::EPIPE, IOError => e
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
