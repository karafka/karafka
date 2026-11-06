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
    module Actions
      # Holds the actions this installation can run, by their names
      class Registry
        include Enumerable

        def initialize
          @actions = {}
          @mutex = Mutex.new
        end

        # Registers an action. An action with an already registered name replaces the registered
        # one only when it inherits from it.
        #
        # @param action [Class] action class
        def add(action)
          raise(Errors::InvalidActionError, action) unless action < Read

          @mutex.synchronize do
            name = action.action_name
            current = @actions[name]

            raise(Errors::InvalidActionError, action) if current && !(action <= current)

            @actions[name] = action
          end
        end

        # @param name [String] action name
        # @return [Class] registered action
        def fetch(name)
          @actions.fetch(name.to_s) { raise(Errors::UnknownActionError, name) }
        end

        # @param block [Proc] code to run on each action
        def each(&block)
          @actions.values.sort_by(&:action_name).each(&block)
        end

        # Removes all the actions
        def clear
          @mutex.synchronize { @actions.clear }
        end
      end
    end
  end
end
