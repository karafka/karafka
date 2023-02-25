# frozen_string_literal: true

require_relative 'metrics_listener'

module Karafka
  module Instrumentation
    # Namespace for vendor specific instrumentation
    module Vendors
      # Datadog specific instrumentation
      module Datadog
        # Alias to keep backwards compatibility
        Listener = MetricsListener
      end
    end
  end
end
