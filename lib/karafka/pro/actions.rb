# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

module Karafka
  module Pro
    # Protocol-neutral operations on a Karafka installation. Each action declares its arguments
    # and whether it reads or writes, so adapters (like the `karafka query` CLI) can expose it
    # without knowing its internals.
    #
    # Actions are registered explicitly when Pro sets up, not when their classes are loaded.
    module Actions
      # Actions provided by Karafka itself
      CORE = [
        Cluster,
        Lags,
        Routing,
        Topic,
        Topics
      ].freeze

      private_constant :CORE

      class << self
        # @return [Registry] registry with all the actions this installation can run
        def registry
          @registry ||= Registry.new
        end

        # @param _config [Karafka::Core::Configurable::Node] root node config
        def pre_setup(_config)
          true
        end

        # Registers core actions and the event published for each action execution
        #
        # @param _config [Karafka::Core::Configurable::Node] root node config
        def post_setup(_config)
          bus = Karafka.monitor.notifications_bus
          bus.register_event("action.executed") unless bus.available_events.include?("action.executed")

          CORE.each { |action| registry.add(action) }
        end

        # This feature does not need any changes post-fork
        #
        # @param _config [Karafka::Core::Configurable::Node]
        # @param _pre_fork_producer [WaterDrop::Producer]
        def post_fork(_config, _pre_fork_producer)
          true
        end
      end
    end
  end
end
