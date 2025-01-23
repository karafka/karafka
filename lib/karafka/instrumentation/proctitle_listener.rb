# frozen_string_literal: true

module Karafka
  module Instrumentation
    # Listener that sets a proc title with a nice descriptive value
    class ProctitleListener
      include Helpers::ConfigImporter.new(
        client_id: %i[client_id]
      )

      Status::STATES.each_key do |state|
        class_eval <<~RUBY, __FILE__, __LINE__ + 1
          # Updates proc title to an appropriate state
          def on_app_#{state}(_event)
            setproctitle('#{state}')
          end
        RUBY
      end

      private

      # Sets a proper proc title with our constant prefix
      # @param status [String] any status we want to set
      def setproctitle(status)
        ::Process.setproctitle(
          "karafka #{client_id} (#{status})"
        )
      end
    end
  end
end
