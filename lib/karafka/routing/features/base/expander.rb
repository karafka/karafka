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

                each do |consumer_group|
                  if scope::Contracts.const_defined?('ConsumerGroup', false)
                    scope::Contracts::ConsumerGroup.new.validate!(consumer_group.to_h)
                  end

                  next unless scope::Contracts.const_defined?('Topic', false)

                  consumer_group.topics.each do |topic|
                    scope::Contracts::Topic.new.validate!(topic.to_h)
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
