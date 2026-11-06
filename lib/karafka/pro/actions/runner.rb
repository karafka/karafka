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
      # Runs registered actions and wraps their output (or failure) in a `Result`. Shared by all
      # the adapters, so each of them validates, instruments and reports the same way.
      class Runner
        include Karafka::Core::Helpers::Time

        # Error messages may contain data from payloads, so we only expose their beginning
        MAX_ERROR_MESSAGE_SIZE = 500

        # Ruby classes that given argument types accept
        TYPES = {
          string: String,
          integer: Integer
        }.freeze

        private_constant :MAX_ERROR_MESSAGE_SIZE, :TYPES

        # @param adapter [String] name of the interface running the actions (like `cli`)
        # @param registry [Registry] registry with actions we can run
        def initialize(adapter:, registry: Actions.registry)
          @adapter = adapter
          @registry = registry
        end

        # @param name [String] name of the action
        # @param args [Hash] action arguments
        # @return [Result] action result
        def call(name, args = {})
          payload = { action: name.to_s, args: args, adapter: @adapter }

          Karafka.monitor.instrument("actions.action.executed", payload) do
            payload[:result] = execute(name.to_s, args)
          end
        end

        private

        # @param name [String] name of the action
        # @param args [Hash] action arguments
        # @return [Result] action result
        def execute(name, args)
          started_at = monotonic_now
          action = @registry.fetch(name)
          output = action.new.call(**normalize(action, args))
          meta = { sources: action.sources, query_time_ms: elapsed(started_at) }

          if output.is_a?(Base::Page)
            meta.merge!(page: output.page, per_page: output.per_page, has_more: output.has_more)
            output = output.rows
          end

          Result.new(ok: true, data: output, meta: meta)
        rescue Errors::UnknownActionError => e
          failure("unknown_action", { action: e.message }, started_at)
        rescue Errors::InvalidArgsError => e
          failure("invalid_args", { value: e.message }, started_at)
        rescue Errors::NotFoundError => e
          failure("not_found", { value: e.message }, started_at)
        rescue => e
          failure(
            "failed",
            { class: e.class.name, message: e.message.to_s[0, MAX_ERROR_MESSAGE_SIZE] },
            started_at
          )
        end

        # Checks the arguments against the action declarations
        #
        # @param action [Class] action class
        # @param args [Hash] raw arguments
        # @return [Hash{Symbol => Object}] arguments for the action
        def normalize(action, args)
          args = args.transform_keys(&:to_sym)
          declared = action.args

          args.each do |name, value|
            details = declared.fetch(name) { raise(Errors::InvalidArgsError, name) }

            raise(Errors::InvalidArgsError, name) unless value.is_a?(TYPES.fetch(details[:type]))
          end

          declared.each do |name, details|
            next unless details[:required]
            next if args.key?(name)

            raise(Errors::InvalidArgsError, name)
          end

          args
        end

        # @param error [String] error code
        # @param details [Hash] error details
        # @param started_at [Float] monotonic time when the execution started
        # @return [Result] failed result
        def failure(error, details, started_at)
          Result.new(
            ok: false,
            error: error,
            details: details,
            meta: { query_time_ms: elapsed(started_at) }
          )
        end

        # @param started_at [Float] monotonic time when the execution started
        # @return [Integer] milliseconds since the start
        def elapsed(started_at)
          (monotonic_now - started_at).round
        end
      end
    end
  end
end
