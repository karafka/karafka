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
            features.each(&:activate)
          end

          # @param config [Karafka::Core::Configurable::Node] app config that we can alter with
          #   particular routing feature specific stuff if needed
          def pre_setup_all(config)
            features.each { |feature| feature.pre_setup(config) }
          end

          # Runs post setup routing features configuration operations
          #
          # @param config [Karafka::Core::Configurable::Node]
          def post_setup_all(config)
            features.each { |feature| feature.post_setup(config) }
          end

          private

          # @return [Array<Class>] all available routing features
          def features
            ObjectSpace
              .each_object(Class)
              .select { |klass| klass < self }
              .sort_by(&:to_s)
          end

          protected

          # Runs pre-setup configuration of a particular routing feature
          #
          # @param _config [Karafka::Core::Configurable::Node] app config node
          def pre_setup(_config)
            true
          end

          # Runs post-setup configuration of a particular routing feature
          #
          # @param _config [Karafka::Core::Configurable::Node] app config node
          def post_setup(_config)
            true
          end
        end
      end
    end
  end
end
