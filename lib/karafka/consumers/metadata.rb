# frozen_string_literal: true

module Karafka
  module Consumers
    module Metadata
      def metadata=(metadata)
        @metadata = metadata
      end

      def metadata
        @metadata
      end
    end
  end
end
