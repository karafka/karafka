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
    # Pro related CLI commands
    module Cli
      # CLI entry-point for parallel segments management commands
      class ParallelSegments < Karafka::Cli::Base
        include Helpers::Colorize
        include Helpers::ConfigImporter.new(
          kafka_config: %i[kafka]
        )

        desc 'Allows for parallel segments management'

        option(
          :groups,
          'Names of consumer groups on which we want to run the command. All if not provided',
          Array,
          %w[
            --groups
            --consumer_groups
          ]
        )

        # Some operations may not be allowed to run again after data is set in certain ways.
        # For example if a distribution command is invoked when the parallel group segment
        # consumer groups already have offsets set, we will fail unless user wants to force it.
        # This prevents users from accidentally running the command in such ways that would cause
        # their existing distributed offsets to be reset.
        option(
          :force,
          'Should an operation on the parallel segments consumer group be forced',
          TrueClass,
          %w[
            --force
          ]
        )

        # @param action [String] action we want to take
        def call(action = 'distribute')
          case action
          when 'distribute'
            Distribute.new(options).call
          when 'collapse'
            Collapse.new(options).call
          when 'reset'
            Collapse.new(options).call
            Distribute.new(options).call
          else
            raise ArgumentError, "Invalid topics action: #{action}"
          end
        end
      end
    end
  end
end
