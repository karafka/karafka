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
    module Routing
      module Features
        class Filtering < Base
          # Filtering feature topic extensions
          module Topic
            # This method sets up the extra instance variable to nil before calling
            # the parent class initializer. The explicit initialization
            # to nil is included as an optimization for Ruby's object shapes system,
            # which improves memory layout and access performance.
            def initialize(...)
              @filtering = nil
              super
            end

            # @param factory [#call, nil] Callable that can produce new filters instances per
            #   assigned topic partition. nil as default so this feature is disabled
            def filter(factory = nil)
              @filtering ||= Config.new(factories: [])
              @filtering.factories << factory if factory
              @filtering
            end

            # @return [Filtering::Config] alias to match the naming API for features
            def filtering(*)
              filter(*)
            end

            # @return [Boolean] is a given job throttled
            def filtering?
              filtering.active?
            end

            # @return [Hash] topic with all its native configuration options plus throttling
            def to_h
              super.merge(
                filtering: filtering.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
