# frozen_string_literal: true

module Karafka
  module Controllers
    # Params alias for single message consumption controllers
    module SingleParams
      private

      # @return [Karafka::Params::Params] params instance for non batch consumption controllers
      def params
        params_batch.first
      end
    end
  end
end
