# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Base
        # Routing builder expander that injects feature related drawing operations into it
        class Expander < Module
          # Resolves the feature contracts namespace (holding `Group`/`Topic`) for a group's mode,
          # mirroring the routing namespaces. A mode-specific feature exposes kind-only contracts
          # (`Contracts::Group`/`Contracts::Topic`) and only applies to its own mode; a shared
          # feature exposes mode-qualified contracts (`Contracts::ConsumerGroups::{Group,Topic}` /
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
            else
              mod_name = (mode == :share) ? "ShareGroups" : "ConsumerGroups"

              contracts.const_defined?(mod_name, false) ? contracts.const_get(mod_name, false) : nil
            end
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
                  mode = group.share_group? ? :share : :consumer
                  contracts = Base::Expander.contracts_for(scope, mode)

                  next unless contracts

                  if contracts.const_defined?("Group", false)
                    contracts::Group.new.validate!(
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
end
