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
          module Topic
            # Allows for direct assignment of
            def assign(*partitions_or_all)
              @direct_assignments ||= if partitions_or_all == [true]
                Config.new(
                  active: true,
                  partitions: true
                )
              else
                Config.new(
                  active: !partitions_or_all.empty?,
                  partitions: partitions_or_all.map { |partition| [partition, true] }.to_h
                )
              end
            end

            # @return [DirectAssignments::Config]
            def direct_assignments
              assign
            end

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
