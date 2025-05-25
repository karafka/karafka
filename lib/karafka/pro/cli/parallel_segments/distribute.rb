# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Cli
      class ParallelSegments < Karafka::Cli::Base
        # Command that makes it easier for users to migrate from regular consumer groups to
        # the parallel segments consumers groups by automatically distributing offsets based on
        # the used "normal" consumer group.
        #
        # Takes the segments origin consumer group offsets for a given set of topics and
        # distributes those offsets onto the parallel segments consumer groups, so they can pick
        # up where the origin group left.
        #
        # To make sure users do not accidentally "re-distribute" their offsets from the original
        # consumer group after the parallel consumer groups had offsets assigned and started to
        # work, we check if the parallel groups have any offsets, if so unless forced we halt.
        #
        # @note This command does not remove the original consumer group from Kafka. We keep it
        #   just as a backup. User can remove it himself.
        #
        # @note Kafka has no atomic operations this is why we first collect all the data and run
        #   needed validations before applying offsets.
        class Distribute < Base
          # Runs the distribution process
          def call
            puts 'Starting parallel segments distribution...'

            segments_count = applicable_groups.size

            if segments_count.zero?
              puts "#{red('No')} consumer groups with parallel segments configuration found"

              return
            end

            puts(
              "Found #{green(segments_count)} consumer groups with parallel segments configuration"
            )

            distributions = []

            applicable_groups.each do |segment_origin, segments|
              puts
              puts "Collecting group #{yellow(segment_origin)} details..."
              offsets = collect_offsets(segment_origin, segments)

              unless options.key?(:force)
                puts "Validating group #{yellow(segment_origin)} parallel segments..."
                validate!(offsets, segments)
              end

              puts "Distributing group #{yellow(segment_origin)} offsets..."
              distributions += distribute(offsets, segments)
            end

            distributions.each do |distribution|
              apply(distribution)
            end

            puts
            puts "Distribution completed #{green('successfully')}!"
          end

          private

          # Validates the current state of topics offsets assignments.
          # We want to make sure, that users do not run distribution twice, especially for a
          # parallel segments consumers group set that was already actively consumed. This is why
          # we check if there was any offsets already present in the parallel segments consumer
          # groups and if so, we raise an error. This can be disabled with `--force`.
          #
          # It prevents users from overwriting the already set segments distribution.
          # Adding new topics to the same parallel segments consumer group does not require us to
          # run this at all and on top of that users can always use `--consumer_groups` flag to
          # limit the cgs that we will be operating here
          #
          # @param offsets [Hash]
          # @param segments [Array<Karafka::Routing::ConsumerGroup>]
          def validate!(offsets, segments)
            segments_names = segments.map(&:name)

            offsets.each do |cg_name, topics|
              next unless segments_names.include?(cg_name)

              topics.each do |topic_name, partitions|
                partitions.each do |partition_id, offset|
                  next unless offset.to_i.positive?

                  raise(
                    ::Karafka::Errors::CommandValidationError,
                    "Parallel segment #{red(cg_name)} already has offset #{red(offset)}" \
                    " set for #{red("#{topic_name}##{partition_id}")}"
                  )
                end
              end
            end
          end

          # Computes the offsets distribution for all the segments consumer groups so when user
          # migrates from one CG to parallel segments, those segments know where to start consuming
          # the data.
          #
          # @param offsets [Hash]
          # @param segments [Array<Karafka::Routing::ConsumerGroup>]
          # @note This code does **not** apply the offsets, just computes their positions
          def distribute(offsets, segments)
            distributions = []
            segments_names = segments.map(&:name)

            offsets.each do |cg_name, topics|
              next if segments_names.include?(cg_name)

              distribution = {}

              topics.each do |topic_name, partitions|
                partitions.each do |partition_id, offset|
                  distribution[topic_name] ||= {}
                  distribution[topic_name][partition_id] = offset
                end
              end

              next if distribution.empty?

              segments_names.each do |segment_name|
                distributions << {
                  segment_name: segment_name,
                  distribution: distribution
                }
              end
            end

            distributions
          end

          # Takes the details of the distribution of offsets for a given segment and adjust the
          # starting offsets for all the consumer group topics based on the distribution.
          #
          # @param distribution [Hash]
          def apply(distribution)
            segment_name = distribution[:segment_name]
            alignments = distribution[:distribution]

            puts
            puts "Adjusting offsets of parallel segments consumer group: #{green(segment_name)}"

            alignments.each do |topic_name, partitions|
              puts "  Topic #{green(topic_name)}:"

              partitions.each do |partition_id, offset|
                puts "    Partition #{green(partition_id)}: starting offset #{green(offset)}"
              end
            end

            Karafka::Admin.seek_consumer_group(segment_name, alignments)
          end
        end
      end
    end
  end
end
