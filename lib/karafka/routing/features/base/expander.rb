# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Base
        # Routing builder expander that injects feature related drawing operations into it
        class Expander < Module
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
                  # A feature validates each group with the contract matching that group's type.
                  # Consumer groups use `Contracts::ConsumerGroup` and `Contracts::ConsumerGroupTopic`
                  # (or the legacy `Contracts::Topic` name, kept for external features until 3.0);
                  # share groups use `Contracts::ShareGroup`/`Contracts::ShareGroupTopic`. A feature
                  # only runs against a group type for which it defines a matching contract, so a
                  # feature that applies to a single mode simply omits the other mode's contracts.
                  # The share-group primitives are wired here regardless of whether any feature uses
                  # them yet.
                  if group.share_group?
                    group_contract = "ShareGroup"
                    topic_contracts = %w[ShareGroupTopic]
                  else
                    group_contract = "ConsumerGroup"
                    topic_contracts = %w[ConsumerGroupTopic Topic]
                  end

                  if scope::Contracts.const_defined?(group_contract, false)
                    scope::Contracts.const_get(group_contract, false).new.validate!(
                      group.to_h,
                      scope: ["routes", group.name]
                    )
                  end

                  topic_contract = topic_contracts.find do |name|
                    scope::Contracts.const_defined?(name, false)
                  end

                  next unless topic_contract

                  topic_contract_class = scope::Contracts.const_get(topic_contract, false)

                  group.topics.each do |topic|
                    topic_contract_class.new.validate!(
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
