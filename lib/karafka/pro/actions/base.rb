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
      # Base for all the actions. Holds the declarations (name, description and arguments) used
      # by adapters to parse input and to describe the action.
      #
      # @note Do not inherit from this class directly. Use `Read`.
      class Base
        # Mapping of argument types to their JSON Schema types and formats
        JSON_TYPES = {
          string: { type: "string" },
          integer: { type: "integer" },
          regexp: { type: "string", format: "regex" }
        }.freeze

        # Default page size for paginated actions
        DEFAULT_PER_PAGE = 100

        private_constant :DEFAULT_PER_PAGE

        # Paginated subset of action rows with pagination details
        Page = Struct.new(:rows, :page, :per_page, :has_more)

        class << self
          # @param value [String, nil] name to set
          # @return [String, nil] name under which the action is exposed. Inherited, so a
          #   replacement keeps the name of the action it replaces
          def action_name(value = nil)
            @action_name = value if value
            @action_name || (superclass.respond_to?(:action_name) ? superclass.action_name : nil)
          end

          # @param value [String, nil] description to set
          # @return [String, nil] what the action returns
          def description(value = nil)
            @description = value if value
            @description || (superclass.respond_to?(:description) ? superclass.description : nil)
          end

          # @param values [Array<Symbol>] sources to set
          # @return [Array<String>] where the action takes its data from (like `broker`)
          def sources(*values)
            @sources = values.map(&:to_s).freeze unless values.empty?
            @sources || (superclass.respond_to?(:sources) ? superclass.sources : [].freeze)
          end

          # Declares an argument of the action
          #
          # @param name [Symbol] argument name
          # @param type [Symbol] argument type (key of `JSON_TYPES`)
          # @param description [String] argument description
          # @param required [Boolean] is this argument required
          def arg(name, type:, description:, required: false)
            args[name] = { type: type, description: description, required: required }.freeze
          end

          # Declares `page` and `per_page` arguments used for paginating unbounded results
          def paginated
            arg :page, type: :integer, description: "Page number, starting from 1"
            arg :per_page, type: :integer, description: "Rows per page (max #{Contracts::Pagination::MAX_PER_PAGE})"
          end

          # @return [Hash{Symbol => Hash}] arguments declarations, including the inherited ones
          def args
            @args ||= superclass.respond_to?(:args) ? superclass.args.dup : {}
          end

          # @return [Hash] JSON Schema of the action arguments
          def schema
            {
              type: "object",
              properties: args.to_h do |name, details|
                [
                  name.to_s,
                  JSON_TYPES.fetch(details[:type]).merge(description: details[:description])
                ]
              end,
              required: args.select { |_, details| details[:required] }.keys.map(&:to_s),
              additionalProperties: false
            }
          end

          # @return [Hash] action details for listings
          def to_h
            {
              name: action_name,
              description: description,
              mode: mode.to_s,
              sources: sources,
              args: schema
            }
          end
        end

        # Runs the action with the declared arguments as keywords
        def call
          raise NotImplementedError, "Implement this in a subclass"
        end

        private

        # @param rows [Array] all the rows
        # @param page [Integer, nil] requested page
        # @param per_page [Integer, nil] requested page size
        # @return [Page] requested page of rows
        def paginate(rows, page: nil, per_page: nil)
          page ||= 1
          per_page ||= DEFAULT_PER_PAGE

          offset = (page - 1) * per_page

          Page.new(
            rows[offset, per_page] || [],
            page,
            per_page,
            rows.size > offset + per_page
          )
        end
      end
    end
  end
end
