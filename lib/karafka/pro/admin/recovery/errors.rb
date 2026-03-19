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
    # Pro Admin utilities
    module Admin
      class Recovery < Karafka::Admin
        # Recovery related errors
        module Errors
          # Base for all the recovery errors
          BaseError = Class.new(::Karafka::Errors::BaseError)

          # Raised when required cluster metadata cannot be retrieved (topic, partition, or
          # broker not found)
          MetadataError = Class.new(BaseError)

          # Raised when a partition number is outside the valid range for __consumer_offsets
          PartitionOutOfRangeError = Class.new(BaseError)
        end
      end
    end
  end
end
