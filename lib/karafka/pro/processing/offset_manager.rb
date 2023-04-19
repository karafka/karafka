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
    module Processing
      class OffsetManager
        def initialize
          @groups = []
          @marked = {}
        end

        def clear
          @groups.clear
          @marked = {}
        end

        def register(offsets_group)
          @groups << offsets_group

          offsets_group.each { |offset| @marked[offset] = false }
        end

        def mark_as_consumed(offset)
          group = @groups.find { |group| group.include?(offset) }
          position = group.index(offset)

          group[0..position].each do |offset|
            @marked[offset] = true
          end
        end

        def markable_offset
          highest_ready = -1

          @marked.to_a.sort_by(&:first).to_h.each do |offset, marked|
            return highest_ready unless marked

            highest_ready = offset
          end

          highest_ready
        end
      end
    end
  end
end
