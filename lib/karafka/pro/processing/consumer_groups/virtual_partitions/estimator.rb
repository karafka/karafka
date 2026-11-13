# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

module Karafka
  module Pro
    module Processing
      module ConsumerGroups
        module VirtualPartitions
          # Estimates how well Virtual Partitions would parallelize the data of a topic.
          #
          # It samples the most recent messages of each partition, slices them into batches the
          # way a consumer would receive them and runs each batch through the real Virtual
          # Partitions distributors. It returns plain data only and prints nothing. The result can
          # be saved as a JSON report and displayed with `karafka vps estimate-report`.
          #
          # It does not read the topic routing Virtual Partitions setup. It does not matter if the
          # topic already uses Virtual Partitions or not.
          #
          # @note Applies to consumer groups only. Share groups have no per-key ordering, so this
          #   estimate does not apply to them.
          #
          # @note The estimate assumes the same processing cost for each message. It does not
          #   model the worker pool that is shared with other partitions and topics.
          #
          # @example
          #   vps = Karafka::Pro::Processing::ConsumerGroups::VirtualPartitions
          #   estimator = vps::Estimator.new(
          #     partitioner: ->(message) { message.headers["order_id"] }
          #   )
          #   estimator.call("orders", target_file: "report.json")
          #   # then, in the shell: bundle exec karafka vps estimate-report
          class Estimator
            # Version of the result structure. Raise it whenever the result structure changes in a
            # way the report renderer depends on (keys renamed, removed or added, or a value type or
            # meaning changed).
            FORMAT_VERSION = 1

            # Settings used by the real distributors
            DistributorConfig = Struct.new(:partitioner, :reducer, :max_partitions)

            # Distributors per distribution name
            DISTRIBUTORS = {
              consistent: Distributors::Consistent,
              balanced: Distributors::Balanced
            }.freeze

            private_constant :DistributorConfig, :DISTRIBUTORS

            # @param concurrency [Integer] number of virtual partitions (max partitions) to
            #   estimate for. Defaults to `Karafka::App.config.concurrency`.
            # @param partitioner [#call, nil] virtual partitioner that receives a message. When
            #   `nil`, messages are grouped by `message.raw_key`.
            # @param reducer [#call, nil] reducer used by the `:consistent` distribution. When
            #   `nil`, the routing default (`key.to_s.sum % concurrency`) is used.
            # @param distribution [Symbol] `:consistent` or `:balanced`. Defaults to
            #   `consumer_groups.virtual_partitions.estimator.distribution`.
            # @param batch_size [Integer] number of messages in a batch. Defaults to
            #   `Karafka::App.config.max_messages`.
            # @param sample_size [Integer] number of most recent messages to sample per partition.
            #   Defaults to `consumer_groups.virtual_partitions.estimator.sample_size`.
            # @param details [Boolean] should the result also include per-batch details
            # @raise [Karafka::Errors::InvalidConfigurationError] when settings are invalid
            def initialize(
              concurrency: Karafka::App.config.concurrency,
              partitioner: nil,
              reducer: nil,
              distribution: Karafka::App.config.consumer_groups.virtual_partitions.estimator.distribution,
              batch_size: Karafka::App.config.max_messages,
              sample_size: Karafka::App.config.consumer_groups.virtual_partitions.estimator.sample_size,
              details: false
            )
              Contracts::Estimator.new.validate!(
                {
                  concurrency: concurrency,
                  partitioner: partitioner,
                  reducer: reducer,
                  distribution: distribution,
                  batch_size: batch_size,
                  sample_size: sample_size,
                  details: details
                }
              )

              @concurrency = concurrency
              @partitioner = partitioner || ->(message) { message.raw_key }
              @reducer = reducer || ->(key) { key.to_s.sum % concurrency }
              @batch_size = batch_size
              @sample_size = sample_size
              @distributor_class = DISTRIBUTORS.fetch(distribution)
              @result_builder = ResultBuilder.new(
                settings: {
                  concurrency: concurrency,
                  distribution: distribution,
                  batch_size: batch_size,
                  sample_size: sample_size,
                  custom_partitioner: !partitioner.nil?,
                  custom_reducer: !reducer.nil?
                },
                details: details
              )
            end

            # Reads the most recent messages of the topic partitions and estimates them
            #
            # @param topic_name [String] name of the topic
            # @param partitions [Array<Integer>, nil] partitions to sample. All when `nil`.
            # @param target_file [String, Pathname, nil] path to write the JSON report to. Nothing
            #   is written when nil.
            # @return [Hash] frozen estimation result
            def call(topic_name, partitions: nil, target_file: nil)
              partitions ||= Array.new(
                Karafka::Admin.topic_info(topic_name).fetch(:partition_count)
              ) { |partition| partition }

              messages = partitions.to_h { |partition| [partition, []] }

              iterator = Karafka::Pro::Iterator.new(
                { topic_name => partitions.to_h { |partition| [partition, -@sample_size] } }
              )

              iterator.each { |message| messages[message.partition] << message }

              save(build_result(topic_name, messages), target_file)
            end

            # Estimates given messages without connecting to Kafka
            #
            # @param messages [Array<Karafka::Messages::Message>] messages of one topic
            # @param target_file [String, Pathname, nil] path to write the JSON report to. Nothing
            #   is written when nil.
            # @return [Hash] frozen estimation result
            def analyze(messages, target_file: nil)
              result = build_result(
                messages.first&.topic,
                messages.group_by(&:partition)
              )

              save(result, target_file)
            end

            private

            # @param topic_name [String, nil]
            # @param partitions_messages [Hash{Integer => Array<Karafka::Messages::Message>}]
            # @return [Hash]
            def build_result(topic_name, partitions_messages)
              partitions_batches = partitions_messages.transform_values do |messages|
                messages
                  .sort_by(&:offset)
                  .each_slice(@batch_size)
                  .map { |batch| analyze_batch(batch) }
              end

              @result_builder.call(topic_name, partitions_batches)
            end

            # @param result [Hash] estimation result
            # @param target_file [String, Pathname, nil]
            # @return [Hash] the given result
            def save(result, target_file)
              File.write(target_file, JSON.pretty_generate(result)) if target_file

              result
            end

            # Runs one batch through the distributor the way the real processing does
            #
            # @param batch [Array<Karafka::Messages::Message>]
            # @return [Hash] batch stats
            def analyze_batch(batch)
              collapsed = false

              begin
                keys = batch.to_h { |message| [message, @partitioner.call(message)] }

                groups = if @concurrency > 1
                  # Reuses the computed keys, so the partitioner runs once per message
                  @distributor_class
                    .new(DistributorConfig.new(keys.method(:fetch), @reducer, @concurrency))
                    .call(batch)
                else
                  { 0 => batch }
                end
              rescue
                collapsed = @concurrency > 1
                keys = {}
                groups = { 0 => batch }
              end

              size = batch.size
              sizes = groups.each_value.map(&:size).sort!.reverse!
              largest = sizes.first
              active_vps = sizes.size

              {
                first_offset: batch.first.offset,
                last_offset: batch.last.offset,
                messages: size,
                collapsed: collapsed,
                unique_keys: keys.each_value.uniq.size,
                null_keys: keys.each_value.count(nil),
                active_vps: active_vps,
                group_sizes: sizes,
                utilization: [active_vps * 100.0 / @concurrency, 100.0].min,
                load_imbalance: coefficient_of_variation(sizes),
                parallelization: [size * 100.0 / @concurrency / largest, 100.0].min,
                speedup: size.to_f / largest
              }
            end

            # @param sizes [Array<Integer>] group sizes
            # @return [Float] coefficient of variation of the sizes in %
            def coefficient_of_variation(sizes)
              mean = sizes.sum.fdiv(sizes.size)
              variance = sizes.sum { |size| (size - mean)**2 } / sizes.size

              Math.sqrt(variance) * 100 / mean
            end
          end
        end
      end
    end
  end
end
