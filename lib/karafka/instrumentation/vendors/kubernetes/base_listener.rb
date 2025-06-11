# frozen_string_literal: true

require 'socket'

module Karafka
  module Instrumentation
    module Vendors
      # Namespace for instrumentation related with Kubernetes
      module Kubernetes
        # Base Kubernetes Listener providing basic HTTP server capabilities to respond with health
        # statuses
        class BaseListener
          include ::Karafka::Core::Helpers::Time

          # All good with Karafka
          OK_CODE = '200 OK'

          # Some timeouts, fail
          FAIL_CODE = '500 Internal Server Error'

          private_constant :OK_CODE, :FAIL_CODE

          # @param hostname [String, nil] hostname or nil to bind on all
          # @param port [Integer] TCP port on which we want to run our HTTP status server
          def initialize(
            hostname: nil,
            port: 3000
          )
            @hostname = hostname
            @port = port
          end

          # @return [Boolean] true if all good, false if we should tell k8s to kill this process
          def healthy?
            raise NotImplementedError, 'Implement in a subclass'
          end

          private

          # Responds to a HTTP request with the process liveness status
          def respond
            body = JSON.generate(status_body)

            client = @server.accept
            client.gets
            client.print "HTTP/1.1 #{healthy? ? OK_CODE : FAIL_CODE}\r\n"
            client.print "Content-Type: application/json\r\n"
            client.print "Content-Length: #{body.bytesize}\r\n"
            client.print "\r\n"
            client.print body
            client.close

            true
          rescue Errno::ECONNRESET, Errno::EPIPE, IOError
            !@server.closed?
          end

          # @return [Hash] hash that will be the response body
          def status_body
            {
              status: healthy? ? 'healthy' : 'unhealthy',
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
