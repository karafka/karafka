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
      # Actions related contracts
      module Contracts
        # Checks action arguments against the arguments the action declares
        class Arguments < Karafka::Contracts::Base
          configure do |config|
            config.error_messages = YAML.safe_load_file(
              File.join(Karafka.gem_root, "config", "locales", "pro_errors.yml")
            ).fetch("en").fetch("validations").fetch("actions")
          end

          # @return [Hash{Symbol => Hash}] arguments the action declares
          attr_reader :declarations

          # @param declarations [Hash{Symbol => Hash}] arguments the action declares
          def initialize(declarations)
            super()
            @declarations = declarations
          end

          virtual do |data, _errors, contract|
            (data.keys - contract.declarations.keys).map { |name| [[name], :unknown] }
          end

          virtual do |data, _errors, contract|
            contract.declarations.filter_map do |name, details|
              [[name], :missing] if details[:required] && !data.key?(name)
            end
          end

          virtual do |data, _errors, contract|
            data.filter_map do |name, value|
              details = contract.declarations[name]

              next unless details
              next if contract.valid_type?(details[:type], value)

              [[name], :format]
            end
          end

          # @param type [Symbol] declared argument type
          # @param value [Object] given value
          # @return [Boolean] does the value match the type
          def valid_type?(type, value)
            case type
            when :string then value.is_a?(String)
            when :integer then value.is_a?(Integer)
            when :regexp then value.is_a?(String) && regexp?(value)
            else false
            end
          end

          private

          # @param value [String] regular expression source
          # @return [Boolean] is this a valid regular expression
          def regexp?(value)
            Regexp.new(value)
            true
          rescue RegexpError
            false
          end
        end
      end
    end
  end
end
