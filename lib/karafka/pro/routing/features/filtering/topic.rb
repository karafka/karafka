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
    module Routing
      module Features
        class Filtering < Base
          # Filtering feature topic extensions
          module Topic
            # This method calls the parent class initializer and then sets up the
            # extra instance variable to nil. The explicit initialization
            # to nil is included as an optimization for Ruby's object shapes system,
            # which improves memory layout and access performance.
            def initialize(...)
              super
              @filtering = nil
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
