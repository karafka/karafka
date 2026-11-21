# frozen_string_literal: true

require "karafka/instrumentation/vendors/kubernetes/base_listener"

module Karafka
  module Instrumentation
    module Vendors
      module Kubernetes
        # Kubernetes HTTP listener designed to operate with Karafka running in the swarm mode
        # In the Swarm mode we supervise only the supervisor as other nodes are suppose to be
        # managed by the swarm supervisor
        class SwarmLivenessListener < BaseListener
          # @param hostname [String, nil] hostname or nil to bind on all
          # @param port [Integer] TCP port on which we want to run our HTTP status server
          # @param controlling_ttl [Integer] time in ms after which we consider the supervising
          #   thread dead because it is not controlling nodes. When configuring this, please take
          #   into consideration, that during shutdown of the swarm, there is no controlling
          #   happening.
          # @param client_read_timeout [Integer] time in ms we wait for a client to send the request
          #   line before we close its connection
          def initialize(
            hostname: nil,
            port: 3000,
            controlling_ttl: 60 * 1_000,
            client_read_timeout: DEFAULT_CLIENT_READ_TIMEOUT
          )
            @hostname = hostname
            @port = port
            @controlling_ttl = controlling_ttl
            @controlling = monotonic_now
            super(port: port, hostname: hostname, client_read_timeout: client_read_timeout)
          end

          # Starts reporting in the supervisor only when it runs
          # @param _event [Karafka::Core::Monitoring::Event]
          def on_app_supervising(_event)
            start
          end

          # Tick on each control
          # @param _event [Karafka::Core::Monitoring::Event]
          def on_swarm_manager_control(_event)
            @controlling = monotonic_now
          end

          private

          # Did we exceed any of the ttls
          # @return [String] 204 string if ok, 500 otherwise
          def healthy?
            (monotonic_now - @controlling) < @controlling_ttl
          end

          # @return [Hash] response body status
          def status_body
            super.merge!(
              errors: {
                controlling_ttl_exceeded: !healthy?
              }
            )
          end
        end
      end
    end
  end
end
