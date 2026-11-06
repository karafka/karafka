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
    module Cli
      # CLI entry-point for read-only actions. Prints one JSON envelope for every call, errors
      # included, and runs only `Read` actions.
      #
      # @example List available actions with their arguments schemas
      #   karafka query
      # @example Lags of a consumer group
      #   karafka query lags --consumer_group_id orders
      class Query < Karafka::Cli::Base
        desc "Runs read-only actions and prints their results as JSON"

        # Exit code when the action failed. 1 is what Ruby uses when it crashes
        FAILURE_EXIT_CODE = 1

        # Exit code when the action or its arguments are not valid
        INVALID_EXIT_CODE = 2

        # Exit code when the resource the action was asked about does not exist
        NOT_FOUND_EXIT_CODE = 3

        # Exit codes per result error
        EXIT_CODES = {
          "failed" => FAILURE_EXIT_CODE,
          "invalid_args" => INVALID_EXIT_CODE,
          "unknown_action" => INVALID_EXIT_CODE,
          "not_found" => NOT_FOUND_EXIT_CODE
        }.freeze

        private_constant(
          :FAILURE_EXIT_CODE,
          :INVALID_EXIT_CODE,
          :NOT_FOUND_EXIT_CODE,
          :EXIT_CODES
        )

        # Options depend on the action, so we parse them once we know it
        def initialize
          @options = {}
        end

        # Arguments accepted when listing the actions
        CATALOG_ARGS = %w[help --json --help -h].freeze

        private_constant :CATALOG_ARGS

        # @param action_name [String, nil] action to run. Lists available actions when not given
        def call(action_name = nil)
          result = with_logs_on_stderr do
            (action_name && action_name != "help") ? run(action_name) : catalog
          end

          $stdout.puts(JSON.generate(result.to_h))

          exit(EXIT_CODES.fetch(result.error)) unless result.ok
        end

        private

        # Points the process stdout at stderr while running, so logs (Karafka, librdkafka and
        # custom loggers) do not mix with the envelope
        def with_logs_on_stderr
          stdout = $stdout.dup
          $stdout.flush
          $stdout.reopen($stderr)

          yield
        ensure
          $stdout.flush
          $stdout.reopen(stdout)
          stdout.close
        end

        # @return [Actions::Result] available actions with their arguments schemas
        def catalog
          # Flags given before an action (`query --json lags`) would otherwise list the actions
          unexpected = ARGV[1..].to_a.find { |arg| !CATALOG_ARGS.include?(arg) }

          if unexpected
            return Actions::Result.new(
              ok: false,
              error: "invalid_args",
              details: { value: unexpected },
              meta: {}
            )
          end

          Actions::Result.new(
            ok: true,
            data: { actions: Actions.registry.map(&:to_h) },
            meta: {}
          )
        end

        # @param action_name [String] action to run
        # @return [Actions::Result] action result
        def run(action_name)
          runner = Actions::Runner.new(adapter: "cli")
          action = Actions.registry.find { |registered| registered.action_name == action_name }

          return runner.call(action_name) unless action

          args = parse_args(action)

          return Actions::Result.new(ok: true, data: action.to_h, meta: {}) if args == :help

          runner.call(action_name, args)
        rescue OptionParser::ParseError => e
          Actions::Result.new(ok: false, error: "invalid_args", details: { value: e.args.first })
        end

        # @param action [Class] action class
        # @return [Hash{Symbol => Object}, Symbol] action arguments from the command line or
        #   `:help` when the action details were requested
        def parse_args(action)
          args = {}
          help = false

          parser = OptionParser.new do |opts|
            action.args.each do |name, details|
              type = (details[:type] == :integer) ? Integer : String
              names = ["--#{name} VALUE", "--#{name.to_s.tr("_", "-")} VALUE"].uniq

              opts.on(*names, type, details[:description]) { |value| args[name] = value }
            end

            # Output is always JSON. Accepted so callers can be explicit about it
            opts.on("--json")
            # Replaces the default help printing, so the output stays JSON
            opts.on("-h", "--help") { help = true }
          end

          extra = parser.parse(ARGV[2..] || [])

          raise(OptionParser::NeedlessArgument, extra.first) unless extra.empty?

          help ? :help : args
        end
      end
    end
  end
end
