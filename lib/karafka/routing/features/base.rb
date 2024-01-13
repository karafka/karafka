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
            if const_defined?('Topic', false)
              Topic.prepend(self::Topic)
            end

            if const_defined?('Topics', false)
              Topics.prepend(self::Topics)
            end

            if const_defined?('ConsumerGroup', false)
              ConsumerGroup.prepend(self::ConsumerGroup)
            end

            if const_defined?('Proxy', false)
              Proxy.prepend(self::Proxy)
            end

            if const_defined?('Builder', false)
              Builder.prepend(self::Builder)
            end

            if const_defined?('Contracts', false)
              Builder.prepend(Base::Expander.new(self))
            end

            if const_defined?('SubscriptionGroup', false)
              SubscriptionGroup.prepend(self::SubscriptionGroup)
            end

            if const_defined?('SubscriptionGroupsBuilder', false)
              SubscriptionGroupsBuilder.prepend(self::SubscriptionGroupsBuilder)
            end
          end

          # Loads all the features and activates them once
          def load_all
            return if @loaded

            features.each(&:activate)

            @loaded = true
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

          # @return [Array<Class>] all available routing features that are direct descendants of
          #   the features base.Approach with using `#superclass` prevents us from accidentally
          #   loading Pro components
          def features
            ObjectSpace
              .each_object(Class)
              .select { |klass| klass < self }
              # Ensures, that Pro components are only loaded when we operate in Pro mode. Since
              # outside of specs Zeitwerk does not require them at all, they will not be loaded
              # anyhow, but for specs this needs to be done as RSpec requires all files to be
              # present
              .reject { |klass| Karafka.pro? ? false : klass.superclass != self }
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
