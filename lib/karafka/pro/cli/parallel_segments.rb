# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
            raise ::ArgumentError, "Invalid topics action: #{action}"
          end
        end
      end
    end
  end
end
