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
    # Namespace for Pro routing enhancements
    module Routing
      # Namespace for additional Pro features
      module Features
        # Multiplexing allows for creating multiple subscription groups for the same topic inside
        # of the same subscription group allowing for better parallelism with limited number
        # of processes
        class Multiplexing < Base
          class << self
            # @param _config [Karafka::Core::Configurable::Node] app config node
            def pre_setup(_config)
              # Make sure we use proper unique validator for topics definitions
              Karafka::Routing::Contracts::ConsumerGroup.singleton_class.prepend(
                Patches::Contracts::ConsumerGroup
              )
            end

            # If needed installs the needed listener and initializes tracker
            #
            # @param config [Karafka::Core::Configurable::Node]
            def post_setup(config)
              config.monitor.subscribe("app.before_warmup") do
                Contracts::Routing.new.validate!(
                  config.internal.routing.builder,
                  scope: %w[multiplexing]
                )
              end

              Karafka::App.monitor.subscribe("app.running") do
                # Do not install the manager and listener to control multiplexing unless there is
                # multiplexing enabled and it is dynamic.
                # We only need to control multiplexing when it is in a dynamic state
                next unless Karafka::App
                  .subscription_groups
                  .values
                  .flat_map(&:itself)
                  .any? { |sg| sg.multiplexing? && sg.multiplexing.dynamic? }

                # Subscribe for events and possibility to manage via the Pro connection manager
                # that supports multiplexing
                Karafka.monitor.subscribe(
                  Karafka::Pro::Connection::Multiplexing::Listener.new
                )
              end
            end
          end
        end
      end
    end
  end
end
