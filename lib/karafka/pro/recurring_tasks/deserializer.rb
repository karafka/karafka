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
    module RecurringTasks
      # Recurring Tasks data deserializer. We compress data ourselves because we cannot rely on
      # any external optional features like certain compression types, etc. By doing this that way
      # we can ensure we have full control over the compression.
      #
      # @note We use `symbolize_names` because we want to use the same convention of hash building
      #   for producing, consuming and displaying related data as in other places.
      class Deserializer
        # @param message [::Karafka::Messages::Message]
        # @return [Hash] deserialized data
        def call(message)
          JSON.parse(
            Zlib::Inflate.inflate(message.raw_payload),
            symbolize_names: true
          )
        end
      end
    end
  end
end
