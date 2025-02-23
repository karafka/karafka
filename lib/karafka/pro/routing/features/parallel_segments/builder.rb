# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class ParallelSegments < Base
          # Expansions for the routing builder
          module Builder
            # Builds and saves given consumer group
            # @param group_id [String, Symbol] name for consumer group
            # @param block [Proc] proc that should be executed in the proxy context
            def consumer_group(group_id, &block)
              consumer_group = find { |cg| cg.name == group_id.to_s }

              # Re-opening a CG should not change its parallel setup
              if consumer_group
                super
              else
                # We build a temp consumer group and a target to check if it has parallel segments
                # enabled and if so, we do not add it to the routing but instead we build the
                # appropriate number of parallel segment groups
                temp_consumer_group = ::Karafka::Routing::ConsumerGroup.new(group_id.to_s)
                temp_target = Karafka::Routing::Proxy.new(temp_consumer_group, &block).target
                config = temp_target.parallel_segments

                if config.active?
                  config.count.times do |i|
                    sub_name = [group_id, config.merge_key, i.to_s].join
                    sub_consumer_group = Karafka::Routing::ConsumerGroup.new(sub_name)
                    self << Karafka::Routing::Proxy.new(sub_consumer_group, &block).target
                  end
                # If not parallel segments are not active we go with the default flow
                else
                  super
                end
              end
            end
          end
        end
      end
    end
  end
end
