# frozen_string_literal: true

require_relative 'base'

module Karafka
  module Instrumentation
    module Vendors
      # Namespace for Appsignal instrumentation
      module Appsignal
        # Listener for reporting errors from both consumers and producers
        # Since we have the same API for WaterDrop and Karafka, we can use one listener with
        # independent instances
        class ErrorsListener < Base
          def_delegators :config, :client

          setting :client, default: Client.new

          configure

          # Sends error details to Appsignal
          #
          # @param event [Karafka::Core::Monitoring::Event]
          def on_error_occurred(event)
            client.report_error(event[:error])
          end
        end
      end
    end
  end
end
