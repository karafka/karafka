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
      # Manager that keeps track of our offsets with the virtualization layer that are local
      # to given partition assignment. It allows for easier offset management for virtual
      # virtual partition cases as it provides us ability to mark as consumed and move the
      # real offset behind as expected.
      #
      # @note We still use the regular coordinator "real" offset management as we want to have
      #   them as separated as possible because the real seek offset management is also used for
      #   pausing, filtering and others and should not be impacted by the virtual one
      #
      # @note This manager is **not** thread-safe by itself. It should operate from coordinator
      #   locked locations.
      class VirtualOffsetManager
        attr_reader :groups

        # @param topic [String]
        # @param partition [Integer]
        #
        # @note We need topic and partition because we use a seek message (virtual) for real offset
        #   management. We could keep real message reference but this can be memory consuming
        #   and not worth it.
        def initialize(topic, partition)
          @topic = topic
          @partition = partition
          @groups = []
          @marked = {}
          @real_offset = -1
        end

        # Clears the manager for a next collective operation
        def clear
          @groups.clear
          @marked = {}
          @real_offset = -1
        end

        # Registers an offset group coming from one virtual consumer. In order to move the real
        # underlying offset accordingly, we need to make sure to track the virtual consumers
        # offsets groups independently and only materialize the end result.
        #
        # @param offsets_group [Array<Integer>] offsets from one virtual consumer
        def register(offsets_group)
          @groups << offsets_group

          offsets_group.each { |offset| @marked[offset] = false }
        end

        # Marks given message as marked (virtually consumed).
        # We mark given message offset and other earlier offsets from the same group as done
        # and we can refresh our real offset representation based on that as it might have changed
        # to a newer real offset.
        # @param message [Karafka::Messages::Message] message coming from VP we want to mark
        def mark(message)
          offset = message.offset

          group = @groups.find { |reg_group| reg_group.include?(offset) }

          # This case can happen when someone uses MoM and wants to mark message from a previous
          # batch as consumed. We can add it, since the real offset refresh will point to it
          unless group
            group = [offset]
            @groups << group
          end

          position = group.index(offset)

          # Mark all previous messages from the same group also as virtually consumed
          group[0..position].each do |markable_offset|
            @marked[markable_offset] = true
          end

          # Recompute the real offset representation
          materialize_real_offset
        end

        # Mark all from all groups including the `message`.
        # Useful when operating in a collapsed state for marking
        # @param message [Karafka::Messages::Message]
        def mark_until(message)
          mark(message)

          @groups.each do |group|
            group.each do |offset|
              next if offset > message.offset

              @marked[offset] = true
            end
          end

          materialize_real_offset
        end

        # @return [Array<Integer>] Offsets of messages already marked as consumed virtually
        def marked
          @marked.select { |_, status| status }.map(&:first).sort
        end

        # Is there a real offset we can mark as consumed
        # @return [Boolean]
        def markable?
          !@real_offset.negative?
        end

        # @return [Messages::Seek] markable message for real offset marking
        def markable
          raise Errors::InvalidRealOffsetUsage unless markable?

          Messages::Seek.new(
            @topic,
            @partition,
            @real_offset
          )
        end

        private

        # Recomputes the biggest possible real offset we can have.
        # It picks the the biggest offset that has uninterrupted stream of virtually marked as
        # consumed because this will be the collective offset.
        def materialize_real_offset
          @marked.to_a.sort_by(&:first).each do |offset, marked|
            break unless marked

            @real_offset = offset
          end

          @real_offset = (@marked.keys.min - 1) if @real_offset.negative?
        end
      end
    end
  end
end
