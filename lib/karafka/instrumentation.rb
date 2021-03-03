# frozen_string_literal: true

module Karafka
  # @note Since we can only have one statistics callbacks manager and one error callbacks manager
  # we use WaterDrops one that is already configured.
  module Instrumentation
    class << self
      # Returns a manager for statistics callbacks
      # @return [::WaterDrop::CallbacksManager]
      def statistics_callbacks
        ::WaterDrop::Instrumentation.statistics_callbacks
      end

      # Returns a manager for error callbacks
      # @return [::WaterDrop::CallbacksManager]
      def error_callbacks
        ::WaterDrop::Instrumentation.error_callbacks
      end
    end
  end
end
