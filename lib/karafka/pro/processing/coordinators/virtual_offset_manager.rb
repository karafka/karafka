# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Coordinators
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
          # @param offset_metadata_strategy [Symbol] what metadata should we select. That is,
          #   should we use the most recent or one picked from the offset that is going to be
          #   committed
          #
          # @note We need topic and partition because we use a seek message (virtual) for real
          #   offset management. We could keep real message reference but this can be memory
          #   consuming and not worth it.
          def initialize(topic, partition, offset_metadata_strategy)
            @topic = topic
            @partition = partition
            @groups = []
            @marked = {}
            @offsets_metadata = {}
            @real_offset = -1
            @offset_metadata_strategy = offset_metadata_strategy
            @current_offset_metadata = nil
          end

          # Clears the manager for a next collective operation
          def clear
            @groups.clear
            @offsets_metadata.clear
            @current_offset_metadata = nil
            @marked.clear
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
          # and we can refresh our real offset representation based on that as it might have
          # changed to a newer real offset.
          # @param message [Karafka::Messages::Message] message coming from VP we want to mark
          # @param offset_metadata [String, nil] offset metadata. `nil` if none
          def mark(message, offset_metadata)
            offset = message.offset

            # Store metadata when we materialize the most stable offset
            @offsets_metadata[offset] = offset_metadata
            @current_offset_metadata = offset_metadata

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
              # Set previous messages metadata offset as the offset of higher one for overwrites
              # unless a different metadata were set explicitely
              @offsets_metadata[markable_offset] ||= offset_metadata
              @marked[markable_offset] = true
            end

            # Recompute the real offset representation
            materialize_real_offset
          end

          # Mark all from all groups including the `message`.
          # Useful when operating in a collapsed state for marking
          # @param message [Karafka::Messages::Message]
          # @param offset_metadata [String, nil]
          def mark_until(message, offset_metadata)
            mark(message, offset_metadata)

            @groups.each do |group|
              group.each do |offset|
                next if offset > message.offset

                @offsets_metadata[offset] = offset_metadata
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

          # @return [Array<Messages::Seek, String>] markable message for real offset marking and
          #   its associated metadata
          def markable
            raise Errors::InvalidRealOffsetUsageError unless markable?

            offset_metadata = case @offset_metadata_strategy
                              when :exact
                                @offsets_metadata.fetch(@real_offset)
                              when :current
                                @current_offset_metadata
                              else
                                raise Errors::UnsupportedCaseError, @offset_metadata_strategy
                              end

            [
              Messages::Seek.new(
                @topic,
                @partition,
                @real_offset
              ),
              offset_metadata
            ]
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
end
