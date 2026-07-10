# frozen_string_literal: true

module Karafka
  module Instrumentation
    module Callbacks
      module ConsumerGroups
        # Default statistics decorator used for consumer group statistics decoration.
        #
        # This is a thin subclass (rather than referencing
        # `Karafka::Core::Monitoring::StatisticsDecorator` directly) so it can be swapped out via
        # `config.internal.statistics.decorator_class` for a custom decorator (for example one
        # that also enriches or corrects specific statistics values) without having to alter the
        # callback that uses it.
        class Decorator < Karafka::Core::Monitoring::StatisticsDecorator
        end
      end
    end
  end
end
