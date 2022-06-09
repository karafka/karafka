# frozen_string_literal: true

module Karafka
  module Processing
    class JobsBuilder
      def consume(executor, messages)
        Jobs::Consume.new(executor, messages)
      end

      def revoked(executor)
        Jobs::Revoked.new(executor)
      end

      def shutdown(executor)
        Jobs::Shutdown.new(executor)
      end
    end
  end
end
