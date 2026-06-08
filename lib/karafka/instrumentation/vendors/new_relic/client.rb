# frozen_string_literal: true

module Karafka
  module Instrumentation
    module Vendors
      # Namespace for New Relic instrumentation
      module NewRelic
        # Default client that delegates to the global NewRelic::Agent.
        # Can be replaced with a test double by reassigning `config.client`.
        class Client
          # Records a metric value via NewRelic::Agent.record_metric.
          # Values are aggregated (min/max/avg/count) over each reporting interval.
          #
          # @param name [String] full metric name (already namespaced)
          # @param value [Numeric] metric value
          def record_metric(name, value)
            ::NewRelic::Agent.record_metric(name, value)
          end
        end
      end
    end
  end
end
