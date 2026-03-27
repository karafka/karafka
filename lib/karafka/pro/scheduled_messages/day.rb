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
    module ScheduledMessages
      # Just a simple UTC day implementation.
      # Since we operate on a scope of one day, this allows us to encapsulate when given day ends
      class Day
        # @return [Integer] utc timestamp when this day object was created. Keep in mind, that
        #   this is **not** when the day started but when this object was created.
        attr_reader :created_at
        # @return [Integer] utc timestamp when this day ends (last second of day).
        # Equal to 23:59:59.
        attr_reader :ends_at
        # @return [Integer] utc timestamp when this day starts. Equal to 00:00:00
        attr_reader :starts_at

        # Initializes a day representation for the current UTC day
        def initialize
          @created_at = Time.now.to_i

          time = Time.at(@created_at).utc

          @starts_at = Time.utc(time.year, time.month, time.day).to_i
          @ends_at = @starts_at + 86_399
        end

        # @return [Boolean] did the current day we operate on ended.
        def ended?
          @ends_at < Time.now.to_i
        end
      end
    end
  end
end
