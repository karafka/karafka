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
    module Cli
      # Pro extension for the Topics CLI command
      # Adds health checking functionality to the base topics command
      module Topics
        # Extends the base topics command to add health action support
        module Extension
          # @param action [String] action we want to take
          def call(action = "help")
            if action == "health"
              detailed_exit_code = options.fetch(:detailed_exitcode, false)
              issues_found = Pro::Cli::Topics::Health.new.call

              return unless detailed_exit_code

              # Exit with code 2 if issues found, code 0 if all healthy
              issues_found ? exit(2) : exit(0)
            else
              super
            end
          end
        end
      end
    end
  end
end

# Extend the OSS Topics command with Pro functionality
Karafka::Cli::Topics.prepend(Karafka::Pro::Cli::Topics::Extension)
