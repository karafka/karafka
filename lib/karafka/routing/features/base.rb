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
          # Karafka supports two ways of defining a routing feature, and this method is what tells
          # them apart:
          #
          # 1. **Mode-namespaced feature** (how every built-in Karafka/Karafka-Web feature is
          #    defined): the feature class lives under a mode namespace, e.g.
          #    `Karafka::Routing::Features::ConsumerGroups::Deserializers` or
          #    `...::ShareGroups::Deserializers`. Its mode is read straight off that namespace and
          #    it only needs to define kind-only `Group`/`Topic`/`Contracts` hooks.
          #
          # 2. **Custom feature** (the supported public extension point - see
          #    `spec/integrations/routing/topic_custom_attributes_spec.rb`): the feature class is
          #    defined outside a mode namespace (typically at the top level, e.g.
          #    `class MyFeature < Karafka::Routing::Features::Base`). Its name carries no mode
          #    segment, so `routing_mode` returns `nil`; the feature instead declares which mode(s)
          #    it targets by nesting `ConsumerGroups`/`ShareGroups` sub-modules (see `#activate`).
          #    This lets a single custom feature target one mode or both.
          #
          # `nil` is therefore a meaningful third state ("mode is not encoded in the namespace,
          # look at the sub-modules"), not a missing case - do not collapse it to a default.
          #
          # @return [Symbol, nil] `:consumer`/`:share` for a mode-namespaced feature, or `nil` for
          #   a custom feature defined outside a mode namespace (see cases above)
          def routing_mode
            # `[-2]` is the namespace segment directly wrapping the feature class, i.e. the mode for
            # a mode-namespaced feature. Anything else (custom feature) falls through to `nil`.
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
            # (`Routing::<Mode>::Group` / `Routing::<Mode>::Topic`). The two branches below
            # correspond to the two ways of defining a feature (see `#routing_mode`):
            if routing_mode
              # Mode-namespaced feature (all built-in features): the feature itself holds the
              # kind-only `Group`/`Topic` modules and its mode comes from its namespace.
              activate_group_topic_hooks(self, routing_mode)
            else
              # Custom feature (public extension point): the feature is defined outside a mode
              # namespace, so it declares its target mode(s) by nesting `ConsumerGroups` and/or
              # `ShareGroups` sub-modules. We attach each sub-module that is present, so one custom
              # feature can target a single mode or both.
              %i[consumer share].each do |mode|
                mod_name = (mode == :share) ? "ShareGroups" : "ConsumerGroups"
                next unless const_defined?(mod_name, false)

                activate_group_topic_hooks(const_get(mod_name, false), mode)
              end

              # Legacy custom-feature layout (pre mode-namespaces): a flat `Topic` module and/or a
              # flat `ConsumerGroup` module directly on the feature. Those features predate share
              # groups, so they are consumer-group scoped by definition and keep attaching to the
              # consumer-group routing classes.
              if const_defined?("Topic", false)
                Routing::ConsumerGroups::Topic.prepend(self::Topic)
              end

              if const_defined?("ConsumerGroup", false)
                Routing::ConsumerGroups::Group.prepend(self::ConsumerGroup)
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
              Builder.prepend(Expander.new(self))
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
          #   feature defined under a mode namespace, or its `ConsumerGroups`/`ShareGroups`
          #   sub-module for a feature defined outside one
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
