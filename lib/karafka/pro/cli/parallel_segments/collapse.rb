# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Cli
      class ParallelSegments < Karafka::Cli::Base
        # Takes the committed offset of each parallel segment for each topic and records
        # them back onto the segment origin consumer group. Without `--force` it will raise an
        # error on conflicts. With `--force` it will take the lowest possible offset for each
        # topic partition as the baseline.
        #
        # @note Running this can cause you some double processing if the parallel segments final
        #   offsets are not aligned.
        #
        # @note This will **not** remove the parallel segments consumer groups. Please use the
        #   Admin API if you want them to be removed.
        class Collapse < Base
          # Runs the collapse operation
          def call
            puts 'Starting parallel segments collapse...'

            segments_count = applicable_groups.size

            if segments_count.zero?
              puts "#{red('No')} consumer groups with parallel segments configuration found"

              return
            end

            puts(
              "Found #{green(segments_count)} consumer groups with parallel segments configuration"
            )

            collapses = []

            applicable_groups.each do |segment_origin, segments|
              puts
              puts "Collecting group #{yellow(segment_origin)} details..."
              offsets = collect_offsets(segment_origin, segments)

              unless options.key?(:force)
                puts
                puts "Validating offsets positions for #{yellow(segment_origin)} consumer group..."
                validate!(offsets, segment_origin)
              end

              puts
              puts "Computing collapsed offsets for #{yellow(segment_origin)} consumer group..."
              collapses << collapse(offsets, segments)
            end

            collapses.each do |collapse|
              apply(collapse)
            end

            puts
            puts "Collapse completed #{green('successfully')}!"
          end

          private

          # Computes the lowest possible offset available for each topic partition and sets it
          # on the segment origin consumer group.
          #
          # @param offsets [Hash]
          # @param segments [Array<Karafka::Routing::ConsumerGroup>]
          # @note This code does **not** apply the offsets, just computes their positions
          def collapse(offsets, segments)
            collapse = Hash.new { |h, k| h[k] = {} }
            segments_names = segments.map(&:name)

            offsets.each do |cg_name, topics|
              next unless segments_names.include?(cg_name)

              topics.each do |topic_name, partitions|
                partitions.each do |partition_id, offset|
                  current_lowest_offset = collapse[topic_name][partition_id]

                  next if current_lowest_offset && current_lowest_offset < offset

                  collapse[topic_name][partition_id] = offset
                end
              end
            end

            {
              collapse: collapse,
              segment_origin: segments.first.segment_origin
            }
          end

          # In order to collapse the offsets of parallel segments back to one, we need to know
          # to what offsets to collapse. The issue (that we solve picking lowest when forced)
          # arises when there are more offsets that are not even in parallel segments for one
          # topic partition. We should let user know about this if this happens so he does not
          # end up with double-processing.
          #
          # @param offsets [Hash]
          # @param segment_origin [String]
          def validate!(offsets, segment_origin)
            collapse = Hash.new { |h, k| h[k] = {} }

            offsets.each do |cg_name, topics|
              next if cg_name == segment_origin

              topics.each do |topic_name, partitions|
                partitions.each do |partition_id, offset|
                  collapse[topic_name][partition_id] ||= Set.new
                  collapse[topic_name][partition_id] << offset
                end
              end
            end

            inconclusive = false

            collapse.each do |topic_name, partitions|
              partitions.each do |partition_id, parallel_offsets|
                next if parallel_offsets.size <= 1

                inconclusive = true

                puts(
                  "  Inconclusive offsets for #{red(topic_name)}##{red(partition_id)}:" \
                  " #{parallel_offsets.to_a.join(', ')}"
                )
              end
            end

            return unless inconclusive

            raise(
              ::Karafka::Errors::CommandValidationError,
              "Parallel segments for #{red(segment_origin)} have #{red('inconclusive')} offsets"
            )
          end

          # Applies the collapsed lowest offsets onto the segment origin consumer group
          #
          # @param collapse [Hash]
          def apply(collapse)
            segment_origin = collapse[:segment_origin]
            alignments = collapse[:collapse]

            puts
            puts "Adjusting offsets of segment origin consumer group: #{green(segment_origin)}"

            alignments.each do |topic_name, partitions|
              puts "  Topic #{green(topic_name)}:"

              partitions.each do |partition_id, offset|
                puts "    Partition #{green(partition_id)}: starting offset #{green(offset)}"
              end
            end

            Karafka::Admin.seek_consumer_group(segment_origin, alignments)
          end
        end
      end
    end
  end
end
