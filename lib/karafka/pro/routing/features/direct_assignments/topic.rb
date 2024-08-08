# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

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
              @direct_assignments ||= Config.new(active: true, partitions: nil)
              return @direct_assignments if partitions_or_all.empty?

              if partitions_or_all == [true]
                @direct_assignments.partitions = true
              elsif partitions_or_all.size == 1 && partitions_or_all.first.is_a?(Range)
                partitions_or_all = partitions_or_all.first.to_a

                @direct_assignments.partitions = partitions_or_all.map { |partition| [partition, true] }.to_h
              else
                @direct_assignments.active = !partitions_or_all.empty?
                @direct_assignments.partitions = partitions_or_all.map { |partition| [partition, true] }.to_h
              end
              @direct_assignments
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
