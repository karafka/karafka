# frozen_string_literal: true

module Karafka
  module Instrumentation
    # Listener that sets a proc title with a nice descriptive value
    class ProctitleListener
      # Updates proc title to an initializing one
      # @param _event [Dry::Events::Event] event details including payload
      def on_app_initializing(_event)
        setproctitle('initializing')
      end

      # Updates proc title to a running one
      # @param _event [Dry::Events::Event] event details including payload
      def on_app_running(_event)
        setproctitle('running')
      end

      # Updates proc title to a stopping one
      # @param _event [Dry::Events::Event] event details including payload
      def on_app_stopping(_event)
        setproctitle('stopping')
      end

      private

      # Sets a proper proc title with our constant prefix
      # @param status [String] any status we want to set
      def setproctitle(status)
        ::Process.setproctitle(
          "karafka #{Karafka::App.config.client_id} (#{status})"
        )
      end
    end
  end
end
