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
            Topic.prepend(self::Topic) if const_defined?('Topic', false)
            Topics.prepend(self::Topics) if const_defined?('Topics', false)
            ConsumerGroup.prepend(self::ConsumerGroup) if const_defined?('ConsumerGroup', false)
            Proxy.prepend(self::Proxy) if const_defined?('Proxy', false)
            Builder.prepend(self::Builder) if const_defined?('Builder', false)
            Builder.prepend(Base::Expander.new(self)) if const_defined?('Contracts', false)
          end

          # Loads all the features and activates them
          def load_all
            ObjectSpace
              .each_object(Class)
              .select { |klass| klass < self }
              .sort_by(&:to_s)
              .each(&:activate)
          end
        end
      end
    end
  end
end
