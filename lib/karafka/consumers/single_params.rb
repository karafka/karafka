# frozen_string_literal: true

module Karafka
  module Consumers
    # Params alias for single message consumption consumers
    module SingleParams
      private

      # @return [Karafka::Params::Params] params instance for non batch consumption consumers
      def params
        params_batch.first
      end
    end
  end
end
