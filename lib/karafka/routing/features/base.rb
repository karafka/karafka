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
          # @return [Symbol, nil] routing mode this feature belongs to (`:consumer`/`:share`),
          #   inferred from where the feature is defined (`Features::ConsumerGroups::X` ->
          #   `:consumer`), or `nil` for a shared top-level feature that targets modes explicitly.
          def routing_mode
            case name.to_s.split("::")[-2]
            when "ShareGroups" then :share
            when "ConsumerGroups" then :consumer
            end
          end

          # @param mode [Symbol] `:consumer` or `:share`
          # @return [Module] the matching routing namespace (ConsumerGroups / ShareGroups)
          def routing_mode_namespace(mode)
            (mode == :share) ? Routing::ShareGroups : Routing::ConsumerGroups
          end

          # Extends topic and builder with given feature API
          def activate
            # Group/topic hooks. Their target routing class mirrors the routing namespaces
            # (`Routing::<Mode>::Group` / `Routing::<Mode>::Topic`). A mode-specific feature (one
            # defined under `Features::ConsumerGroups::`/`ShareGroups::`) defines kind-only `Group`
            # and `Topic` modules and its mode is taken from its namespace. A shared top-level
            # feature (e.g. deserializers) spans modes, so it nests `ConsumerGroups`/`ShareGroups`
            # sub-modules holding `Group`/`Topic`.
            if routing_mode
              activate_group_topic_hooks(self, routing_mode)
            else
              %i[consumer share].each do |mode|
                mod_name = (mode == :share) ? "ShareGroups" : "ConsumerGroups"
                next unless const_defined?(mod_name, false)

                activate_group_topic_hooks(const_get(mod_name, false), mode)
              end
            end

            if const_defined?("Topics", false)
              Topics.prepend(self::Topics)
            end

            if const_defined?("Proxy", false)
              Proxy.prepend(self::Proxy)
            end

            if const_defined?("Builder", false)
              Builder.prepend(self::Builder)
            end

            if const_defined?("Contracts", false)
              Builder.prepend(Base::Expander.new(self))
            end

            if const_defined?("SubscriptionGroup", false)
              SubscriptionGroup.prepend(self::SubscriptionGroup)
            end

            if const_defined?("SubscriptionGroupsBuilder", false)
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

          # Prepends a feature's `Group`/`Topic` modules onto the routing classes of a given mode.
          # @param container [Module] module holding `Group`/`Topic` - the feature itself for a
          #   mode-specific feature, or its `ConsumerGroups`/`ShareGroups` sub-module for a shared
          #   one
          # @param mode [Symbol] `:consumer` or `:share`
          def activate_group_topic_hooks(container, mode)
            routing_ns = routing_mode_namespace(mode)

            if container.const_defined?("Group", false)
              routing_ns::Group.prepend(container::Group)
            end

            return unless container.const_defined?("Topic", false)

            routing_ns::Topic.prepend(container::Topic)
          end

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
