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
      # Envelope every action execution returns, successful or not
      class Result
        # Version of the envelope and actions output shape. Change it whenever the shape changes.
        SCHEMA_VERSION = 1

        # @return [String, nil] error code on failure
        attr_reader :error

        # @param success [Boolean] did the action succeed
        # @param data [Object] action output
        # @param meta [Hash] execution details
        # @param error [String, nil] error code on failure
        # @param details [Hash, nil] error details
        def initialize(success:, data: nil, meta: {}, error: nil, details: nil)
          @success = success
          @data = data
          @meta = meta
          @error = error
          @details = details
        end

        # @return [Boolean] did the action succeed
        def success?
          @success
        end

        # @return [Hash] envelope
        def to_h
          envelope = { schema_version: SCHEMA_VERSION, ok: @success }

          if @success
            envelope[:data] = @data
          else
            envelope[:error] = @error
            envelope[:details] = @details
          end

          envelope[:meta] = @meta
          envelope
        end
      end
    end
  end
end
