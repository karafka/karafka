# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      # Routing builder expander that injects feature related drawing operations into it
      class Expander < Module
        # Resolves the feature contracts namespace (holding `Group`/`Topic`) for a group's mode,
        # mirroring the routing namespaces. A feature defined under a mode namespace
        # (`Features::ConsumerGroups::X` / `Features::ShareGroups::X`, how all built-in features are
        # organized) exposes kind-only contracts (`Contracts::Group`/`Contracts::Topic`) that apply
        # only to its own mode. A feature defined outside a mode namespace (e.g. a custom feature)
        # instead exposes mode-qualified contracts (`Contracts::ConsumerGroups::{Group,Topic}` /
        # `Contracts::ShareGroups::{Group,Topic}`).
        #
        # @param scope [Module] the feature
        # @param mode [Symbol] `:consumer` or `:share`
        # @return [Module, nil] contracts namespace holding `Group`/`Topic`, or nil if the feature
        #   has no contracts for this mode
        def self.contracts_for(scope, mode)
          return nil unless scope.const_defined?("Contracts", false)

          contracts = scope::Contracts

          if scope.routing_mode
            return nil unless scope.routing_mode == mode

            contracts
          elsif contracts.const_defined?((mode == :share) ? "ShareGroups" : "ConsumerGroups", false)
            contracts.const_get((mode == :share) ? "ShareGroups" : "ConsumerGroups", false)
          elsif mode == :consumer &&
              (contracts.const_defined?("Topic", false) ||
                contracts.const_defined?("ConsumerGroup", false))
            # Legacy custom-feature layout (pre mode-namespaces): flat `Contracts::Topic` and/or
            # `Contracts::ConsumerGroup` directly on the feature. Those predate share groups, so
            # they apply to consumer groups only.
            contracts
          end
        end

        # Resolves the group-level contract within a feature contracts namespace, supporting both
        # the current `Group` name and the legacy `ConsumerGroup` one used by pre-mode-namespaces
        # custom features.
        #
        # @param contracts [Module] contracts namespace resolved by {.contracts_for}
        # @return [Class, nil] group contract class or nil when the feature has none
        def self.group_contract_for(contracts)
          return contracts::Group if contracts.const_defined?("Group", false)
          return contracts::ConsumerGroup if contracts.const_defined?("ConsumerGroup", false)

          nil
        end

        # @param scope [Module] feature scope in which contract and other things should be
        # @return [Expander] builder expander instance
        def initialize(scope)
          super()
          @scope = scope
        end

        # Builds anonymous module that alters how `#draw` behaves allowing the feature contracts
        # to run.
        # @param mod [::Karafka::Routing::Builder] builder we will prepend to
        def prepended(mod)
          super

          mod.prepend(prepended_module)
        end

        private

        # @return [Module] builds an anonymous module with `#draw` that will alter the builder
        #   `#draw` allowing to run feature context aware code.
        def prepended_module
          scope = @scope

          Module.new do
            # Runs validations related to this feature on a routing resources
            #
            # @param block [Proc] routing defining block
            define_method :draw do |&block|
              result = super(&block)

              each do |group|
                expander = Karafka::Routing::Features::Expander
                contracts = expander.contracts_for(scope, group.group_type)

                next unless contracts

                group_contract = expander.group_contract_for(contracts)

                if group_contract
                  group_contract.new.validate!(
                    group.to_h,
                    scope: ["routes", group.name]
                  )
                end

                next unless contracts.const_defined?("Topic", false)

                group.topics.each do |topic|
                  contracts::Topic.new.validate!(
                    topic.to_h,
                    scope: ["routes", group.name, topic.name]
                  )
                end
              end

              result
            end
          end
        end
      end
    end
  end
end
