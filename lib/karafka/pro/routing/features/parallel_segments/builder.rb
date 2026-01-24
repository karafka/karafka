# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

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
                temp_consumer_group = Karafka::Routing::ConsumerGroup.new(group_id.to_s)
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
