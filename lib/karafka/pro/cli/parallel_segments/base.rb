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
    module Cli
      class ParallelSegments < Karafka::Cli::Base
        # Base class for all the parallel segments related operations
        class Base
          include Helpers::Colorize

          # @param options [Hash] cli flags options
          # @option options [Array<String>] :groups consumer group names to work with
          def initialize(options)
            @options = options
          end

          private

          # @return [Hash]
          attr_reader :options

          # Returns consumer groups for parallel segments with which we should be working
          #
          # @return [Hash{String => Array<Karafka::Routing::ConsumerGroup>}] hash with all parallel
          #   consumer groups as values and names of segments origin consumer group as the key.
          def applicable_groups
            requested_groups = options[:groups].dup || []

            workable_groups = Karafka::App
                              .routes
                              .select(&:parallel_segments?)
                              .group_by(&:segment_origin)

            # Use all if none provided
            return workable_groups if requested_groups.empty?

            applicable_groups = {}

            requested_groups.each do |requested_group|
              workable_group = workable_groups[requested_group]

              if workable_group
                requested_groups.delete(requested_group)
                applicable_groups[requested_group] = workable_group
              else
                raise(
                  Karafka::Errors::ConsumerGroupNotFoundError,
                  "Consumer group #{requested_group} was not found"
                )
              end
            end

            applicable_groups
          end

          # Collects the offsets for the segment origin consumer group and the parallel segments
          # consumers groups. We use segment origin cg offsets as a baseline for the distribution
          # and use existing (if any) parallel segments cgs offsets for validations.
          #
          # @param segment_origin [String] name of the origin consumer group
          # @param segments [Array<Karafka::Routing::ConsumerGroup>]
          # @return [Hash] fetched offsets for all the cg topics for all the consumer groups
          def collect_offsets(segment_origin, segments)
            topics_names = segments.first.topics.map(&:name)
            consumer_groups = [segment_origin, segments.map(&:name)].flatten

            consumer_groups_with_topics = consumer_groups
                                          .to_h { |name| [name, topics_names] }

            lags_with_offsets = Karafka::Admin.read_lags_with_offsets(
              consumer_groups_with_topics
            )

            lags_with_offsets.each do |_cg_name, topics|
              topics.each do |_topic_name, partitions|
                partitions.transform_values! { |details| details[:offset] }
              end
            end

            lags_with_offsets
          end
        end
      end
    end
  end
end
