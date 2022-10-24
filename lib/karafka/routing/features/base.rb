# frozen_string_literal: true

module Karafka
  module Routing
    # Namespace for all the topic related features we support
    #
    # @note Not all the Karafka features need to be defined here as only those that have routing
    #   or other extensions need to be here. That is why we keep (for now) features under the
    #   routing namespace.
    module Features
      # Base for all the features
      class Base
        class << self
          # Extends topic and builder with given feature API
          def activate
            ::Karafka::Routing::Topic.prepend(self::Topic)
            ::Karafka::Routing::Builder.prepend(Base::Builder.new(self))
          end
        end
      end
    end
  end
end