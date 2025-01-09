# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class DirectAssignments < Base
          # Topic extensions for direct assignments
          module Topic
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
                  partitions: partitions_or_all.map { |partition| [partition, true] }.to_h
                )
              else
                Config.new(
                  active: !partitions_or_all.empty?,
                  partitions: partitions_or_all.map { |partition| [partition, true] }.to_h
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
