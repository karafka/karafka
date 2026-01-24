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
    module Processing
      # Namespace for Pro coordinator related sub-components
      module Coordinators
        # Object used to track errors in between executions to be able to build error-type based
        # recovery flows.
        class ErrorsTracker
          include Enumerable

          # @return [Karafka::Routing::Topic] topic of this error tracker
          attr_reader :topic

          # @return [Integer] partition of this error tracker
          attr_reader :partition

          # @return [Hash]
          attr_reader :counts

          # @return [String]
          attr_reader :trace_id

          # Max errors we keep in memory.
          # We do not want to keep more because for DLQ-less this would cause memory-leaks.
          # We do however count per class for granular error counting
          STORAGE_LIMIT = 100

          private_constant :STORAGE_LIMIT

          # @param topic [Karafka::Routing::Topic]
          # @param partition [Integer]
          # @param limit [Integer] max number of errors we want to keep for reference when
          #   implementing custom error handling.
          # @note `limit` does not apply to the counts. They will work beyond the number of errors
          #   occurring
          def initialize(topic, partition, limit: STORAGE_LIMIT)
            @errors = []
            @counts = Hash.new { |hash, key| hash[key] = 0 }
            @topic = topic
            @partition = partition
            @limit = limit
            @trace_id = SecureRandom.uuid
          end

          # Clears all the errors
          def clear
            @errors.clear
            @counts.clear
          end

          # @param error [StandardError] adds the error to the tracker
          def <<(error)
            @errors.shift if @errors.size >= @limit
            @errors << error
            @counts[error.class] += 1
            @trace_id = SecureRandom.uuid
          end

          # @return [Boolean] is the error tracker empty
          def empty?
            @errors.empty?
          end

          # @return [Integer] number of elements
          def size
            # We use counts reference of all errors and not the `@errors` array because it allows
            # us to go beyond the whole errors storage limit
            @counts.values.sum
          end

          # @return [StandardError, nil] last error that occurred or nil if no errors
          def last
            @errors.last
          end

          # Iterates over errors
          def each(&)
            @errors.each(&)
          end

          # @return [Array<StandardError>] array with all the errors that occurred
          def all
            @errors
          end
        end
      end
    end
  end
end
