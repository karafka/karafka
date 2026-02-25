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
        class Swarm < Base
          module Contracts
            # Special contract that validates prior to starting swarm that each node has
            # at least one assignment.
            #
            # It is special because we cannot run it during routing definitions, because we can
            # only run it when all routes are defined and full context is available.
            #
            # This is why we use it before warmup when everything is expected to be configured.
            class Routing < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load_file(
                  File.join(Karafka.gem_root, "config", "locales", "pro_errors.yml")
                ).fetch("en").fetch("validations").fetch("routing")
              end

              # Validates that each node has at least one assignment.
              #
              # @param builder [Karafka::Routing::Builder]
              # @param scope [Array<String>]
              def validate!(builder, scope: [])
                nodes_setup = Hash.new do |h, node_id|
                  h[node_id] = { active: false, node_id: node_id }
                end

                # Initialize nodes in the hash so we can iterate over them
                App.config.swarm.nodes.times { |node_id| nodes_setup[node_id] }
                nodes_setup.freeze

                builder.each do |consumer_group|
                  consumer_group.topics.each do |topic|
                    nodes_setup.each do |node_id, details|
                      next unless topic.active?
                      next unless topic.swarm.nodes.include?(node_id)

                      details[:active] = true
                    end
                  end
                end

                nodes_setup.each_value do |details|
                  super(details, scope: scope)
                end
              end

              virtual do |data, errors|
                next unless errors.empty?
                next if data[:active]

                [[%i[swarm_nodes], :not_used]]
              end
            end
          end
        end
      end
    end
  end
end
