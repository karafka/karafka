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
        # Karafka Pro Swarm extensions to the routing
        # They allow for more granular work assignment in the swarm
        class Swarm < Base
          class << self
            # Binds our routing validation contract prior to warmup in the supervisor, so we can
            # run it when all the context should be there (config + full routing)
            #
            # @param config [Karafka::Core::Configurable::Node]
            def post_setup(config)
              config.monitor.subscribe('app.before_warmup') do
                Contracts::Routing.new.validate!(
                  config.internal.routing.builder,
                  scope: %w[swarm]
                )
              end
            end
          end
        end
      end
    end
  end
end
