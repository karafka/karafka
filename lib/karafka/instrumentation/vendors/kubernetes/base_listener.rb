# frozen_string_literal: true

require "socket"

module Karafka
  module Instrumentation
    module Vendors
      # Namespace for instrumentation related with Kubernetes
      module Kubernetes
        # Base Kubernetes Listener providing basic HTTP server capabilities to respond with health
        # statuses
        class BaseListener
          include Karafka::Core::Helpers::Time

          # All good with Karafka
          OK_CODE = "200 OK"

          # Some timeouts, fail
          FAIL_CODE = "500 Internal Server Error"

          # Default time in ms we wait for a client to send the request line
          DEFAULT_CLIENT_READ_TIMEOUT = 5_000

          # Max number of bytes we read from a client while looking for the request line
          MAX_REQUEST_LINE_LENGTH = 8_192

          private_constant(
            :OK_CODE,
            :FAIL_CODE,
            :DEFAULT_CLIENT_READ_TIMEOUT,
            :MAX_REQUEST_LINE_LENGTH
          )

          # @param hostname [String, nil] hostname or nil to bind on all
          # @param port [Integer] TCP port on which we want to run our HTTP status server
          # @param client_read_timeout [Integer] time in ms we wait for a client to send the request
          #   line before we close its connection. Probes are answered one at a time, so an idle
          #   connection delays the probes that come after it by up to this time
          def initialize(
            hostname: nil,
            port: 3000,
            client_read_timeout: DEFAULT_CLIENT_READ_TIMEOUT
          )
            @hostname = hostname
            @port = port
            @client_read_timeout = client_read_timeout
          end

          # @return [Boolean] true if all good, false if we should tell k8s to kill this process
          def healthy?
            raise NotImplementedError, "Implement in a subclass"
          end

          private

          # Responds to a HTTP request with the process liveness status
          def respond
            client = @server.accept

            return true unless read_request_line(client)

            # Compute body after accepting so it reflects current health at request time.
            # Derive the HTTP status code from the same snapshot to guarantee consistency -
            # calling healthy? separately could observe a different state.
            snapshot = status_body
            body = JSON.generate(snapshot)
            code = (snapshot[:status] == "healthy") ? OK_CODE : FAIL_CODE
            client.print "HTTP/1.1 #{code}\r\n"
            client.print "Content-Type: application/json\r\n"
            client.print "Content-Length: #{body.bytesize}\r\n"
            client.print "\r\n"
            client.print body

            true
          rescue SystemCallError, IOError
            !@server.closed?
          ensure
            client&.close
          end

          # Reads the request line without `gets`, because `gets` blocks with no timeout and no size
          # limit. Probes are served one at a time, so one idle or slow connection would block all
          # the later probes until it closes, and a client could make us buffer a line of any length
          #
          # @param client [TCPSocket]
          # @return [String, nil] request line or nil when the client did not send one in time, sent
          #   a too long one or disconnected
          def read_request_line(client)
            deadline = monotonic_now + @client_read_timeout
            buffer = "".b

            loop do
              newline = buffer.index("\n")
              return buffer[0..newline] if newline
              return nil if buffer.bytesize >= MAX_REQUEST_LINE_LENGTH

              remaining = deadline - monotonic_now
              return nil if remaining <= 0
              return nil unless client.wait_readable(remaining / 1_000.0)

              chunk = client.read_nonblock(
                MAX_REQUEST_LINE_LENGTH - buffer.bytesize,
                exception: false
              )

              return nil if chunk.nil?

              buffer << chunk if chunk.is_a?(String)
            end
          end

          # @return [Hash] hash that will be the response body
          def status_body
            {
              status: healthy? ? "healthy" : "unhealthy",
              timestamp: Time.now.to_i,
              port: @port,
              process_id: ::Process.pid
            }
          end

          # Starts background thread with micro-http monitoring
          def start
            @server = TCPServer.new(*[@hostname, @port].compact)

            Thread.new do
              loop do
                break unless respond
              end
            end
          end

          # Stops the server
          def stop
            @server.close
          end
        end
      end
    end
  end
end
