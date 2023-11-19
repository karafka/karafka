# frozen_string_literal: true

require_relative 'client'

module Karafka
  module Instrumentation
    module Vendors
      # Namespace for Appsignal instrumentation
      module Appsignal
        # Base for all the instrumentation listeners
        class Base
          include ::Karafka::Core::Configurable
          extend Forwardable

          # @param block [Proc] configuration block
          def initialize(&block)
            configure
            setup(&block) if block
          end

          # @param block [Proc] configuration block
          # @note We define this alias to be consistent with `Karafka#setup`
          def setup(&block)
            configure(&block)
          end
        end
      end
    end
  end
end
