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
        class DirectAssignments < Base
          # Topic extensions for direct assignments
          module Topic
            # This method calls the parent class initializer and then sets up the
            # extra instance variable to nil. The explicit initialization
            # to nil is included as an optimization for Ruby's object shapes system,
            # which improves memory layout and access performance.
            def initialize(...)
              super
              @direct_assignments = nil
            end

            # Allows for direct assignment of
            # @param partitions_or_all [true, Array<Integer>] informs Karafka that we want
            #   to use direct assignments instead of automatic for this topic. It also allows us
            #   to specify which partitions we're interested in or `true` if in all
            #
            # @example Assign all available partitions
            #   direct_assignments(true)
            #
            # @example Assign partitions 2, 3 and 5
            #   direct_assignments(2, 3, 5)
            #
            # @example Assign partitions from 0 to 3
            #   direct_assignments(0..3)
            def direct_assignments(*partitions_or_all)
              @direct_assignments ||= if partitions_or_all == [true]
                Config.new(
                  active: true,
                  partitions: true
                )
              elsif partitions_or_all.size == 1 && partitions_or_all.first.is_a?(Range)
                partitions_or_all = partitions_or_all.first.to_a

                Config.new(
                  active: true,
                  partitions: partitions_or_all.to_h { |partition| [partition, true] }
                )
              else
                Config.new(
                  active: !partitions_or_all.empty?,
                  partitions: partitions_or_all.to_h { |partition| [partition, true] }
                )
              end
            end

            alias assign direct_assignments

            # @return [Hash] topic with all its native configuration options plus direct
            #   assignments
            def to_h
              super.merge(
                direct_assignments: direct_assignments.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
