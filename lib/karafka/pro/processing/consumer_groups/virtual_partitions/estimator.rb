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
          # Partitions distributors. It returns plain data only and prints nothing. Use
          # {Estimator::Presenter} to turn the result into a readable report.
          #
          # It does not read the topic routing Virtual Partitions setup. It does not matter if the
          # topic already uses Virtual Partitions or not.
          #
          # @note Applies to consumer groups only. Share groups have no per-key ordering, so this
          #   estimate does not apply to them.
          #
          # @note The estimate assumes the same processing cost for each message. It does not
          #   model the GVL (CPU-bound work does not run in parallel in one process) or the worker
          #   pool that is shared with other partitions and topics.
          #
          # @example Estimate for all partitions of a topic
          #   vps = Karafka::Pro::Processing::ConsumerGroups::VirtualPartitions
          #   estimator = vps::Estimator.new(
          #     partitioner: ->(message) { message.headers["order_id"] }
          #   )
          #   result = estimator.call("orders")
          #   puts vps::Estimator::Presenter.new(result).to_s
          class Estimator
            # Minimum score for the `:recommended` verdict
            RECOMMENDED_SCORE = 70

            # Minimum score for the `:maybe` verdict
            MAYBE_SCORE = 40

            # Weights of the score components. They sum up to 100.
            SCORE_WEIGHTS = {
              utilization: 40,
              parallelization: 30,
              balance: 20,
              stability: 10
            }.freeze

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
            # @param distribution [Symbol] `:consistent` or `:balanced`
            # @param batch_size [Integer] number of messages in a batch. Defaults to
            #   `Karafka::App.config.max_messages`.
            # @param sample_size [Integer] number of most recent messages to sample per partition
            # @param details [Boolean] should the result also include per-batch details
            # @raise [Karafka::Errors::InvalidConfigurationError] when settings are invalid
            def initialize(
              concurrency: Karafka::App.config.concurrency,
              partitioner: nil,
              reducer: nil,
              distribution: :consistent,
              batch_size: Karafka::App.config.max_messages,
              sample_size: 10_000,
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
              @custom_partitioner = !partitioner.nil?
              @custom_reducer = !reducer.nil?
              @partitioner = partitioner || ->(message) { message.raw_key }
              @reducer = reducer || ->(key) { key.to_s.sum % concurrency }
              @distribution = distribution
              @batch_size = batch_size
              @sample_size = sample_size
              @details = details

              @distributor = DISTRIBUTORS.fetch(distribution).new(
                DistributorConfig.new(@partitioner, @reducer, concurrency)
              )
            end

            # Reads the most recent messages of the topic partitions and estimates them
            #
            # @param topic [String] topic name
            # @param partitions [Array<Integer>, nil] partitions to sample. All when `nil`.
            # @return [Hash] frozen estimation result
            def call(topic, partitions: nil)
              partitions ||= Array.new(
                Karafka::Admin.topic_info(topic).fetch(:partition_count)
              ) { |partition| partition }

              messages = partitions.to_h { |partition| [partition, []] }

              iterator = Karafka::Pro::Iterator.new(
                { topic => partitions.to_h { |partition| [partition, -@sample_size] } }
              )

              iterator.each { |message| messages[message.partition] << message }

              build_result(topic, messages)
            end

            # Estimates given messages without connecting to Kafka
            #
            # @param messages [Array<Karafka::Messages::Message>] messages of one topic
            # @return [Hash] frozen estimation result
            def analyze(messages)
              build_result(
                messages.first&.topic,
                messages.group_by(&:partition)
              )
            end

            private

            # @param topic [String, nil]
            # @param partitions_messages [Hash{Integer => Array<Karafka::Messages::Message>}]
            # @return [Hash]
            def build_result(topic, partitions_messages)
              all_batches = []

              partitions = partitions_messages.sort.to_h do |partition, messages|
                batches = messages
                  .sort_by(&:offset)
                  .each_slice(@batch_size)
                  .map { |batch| analyze_batch(batch) }

                all_batches.concat(batches)

                [partition, aggregate(batches)]
              end

              deep_freeze(
                topic: topic,
                settings: {
                  concurrency: @concurrency,
                  distribution: @distribution,
                  batch_size: @batch_size,
                  sample_size: @sample_size,
                  custom_partitioner: @custom_partitioner,
                  custom_reducer: @custom_reducer
                },
                partitions: partitions,
                summary: aggregate(all_batches, details: false)
              )
            end

            # Runs one batch through the distributor the way the real processing does
            #
            # @param batch [Array<Karafka::Messages::Message>]
            # @return [Hash] batch stats
            def analyze_batch(batch)
              collapsed = false

              begin
                keys = batch.map { |message| @partitioner.call(message) }
                groups = (@concurrency > 1) ? @distributor.call(batch) : { 0 => batch }
              rescue
                collapsed = @concurrency > 1
                keys = []
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
                unique_keys: keys.uniq.size,
                null_keys: keys.count(nil),
                active_vps: active_vps,
                group_sizes: sizes,
                utilization: [active_vps * 100.0 / @concurrency, 100.0].min,
                load_imbalance: coefficient_of_variation(sizes),
                parallelization: [size * 100.0 / @concurrency / largest, 100.0].min,
                speedup: size.to_f / largest
              }
            end

            # @param batches [Array<Hash>] batches stats
            # @param details [Boolean] should we include batches details
            # @return [Hash] aggregated stats
            def aggregate(batches, details: @details)
              count = batches.size

              result = {
                messages: batches.sum { |batch| batch[:messages] },
                batches: count,
                collapsed_batches: batches.count { |batch| batch[:collapsed] }
              }

              if count.zero?
                result[:score] = nil
                result[:verdict] = nil
                result[:batches_details] = [] if details

                return result
              end

              active_vps = batches.map { |batch| batch[:active_vps] }.sort!

              result.merge!(
                avg_unique_keys: average(batches, :unique_keys),
                avg_null_keys: average(batches, :null_keys),
                avg_active_vps: average(batches, :active_vps),
                avg_utilization: average(batches, :utilization),
                avg_load_imbalance: average(batches, :load_imbalance),
                avg_parallelization: average(batches, :parallelization),
                avg_speedup: average(batches, :speedup),
                active_vps: {
                  min: active_vps.first,
                  median: active_vps[active_vps.size / 2],
                  max: active_vps.last
                },
                poor_batches: batches.count { |batch| batch[:active_vps] < @concurrency / 2.0 },
                single_vp_batches: batches.count { |batch| batch[:active_vps] == 1 }
              )

              result[:score] = score(result)
              result[:verdict] = verdict(result[:score])
              result[:batches_details] = batches if details

              result
            end

            # @param stats [Hash] aggregated stats
            # @return [Integer] score from 0 to 100
            def score(stats)
              balance = [100.0 - stats[:avg_load_imbalance], 0.0].max
              stability = 100.0 - (stats[:poor_batches] * 100.0 / stats[:batches])

              (
                stats[:avg_utilization] * SCORE_WEIGHTS[:utilization] +
                stats[:avg_parallelization] * SCORE_WEIGHTS[:parallelization] +
                balance * SCORE_WEIGHTS[:balance] +
                stability * SCORE_WEIGHTS[:stability]
              ).fdiv(100).round
            end

            # @param score [Integer]
            # @return [Symbol]
            def verdict(score)
              if score >= RECOMMENDED_SCORE
                :recommended
              elsif score >= MAYBE_SCORE
                :maybe
              else
                :not_recommended
              end
            end

            # @param sizes [Array<Integer>] group sizes
            # @return [Float] coefficient of variation of the sizes in %
            def coefficient_of_variation(sizes)
              mean = sizes.sum.fdiv(sizes.size)
              variance = sizes.sum { |size| (size - mean)**2 } / sizes.size

              Math.sqrt(variance) * 100 / mean
            end

            # @param batches [Array<Hash>]
            # @param key [Symbol]
            # @return [Float] average of the key values rounded to one decimal place
            def average(batches, key)
              (batches.sum { |batch| batch[key] }.to_f / batches.size).round(1)
            end

            # @param object [Object]
            # @return [Object] deeply frozen object
            def deep_freeze(object)
              case object
              when Hash then object.each_value { |value| deep_freeze(value) }
              when Array then object.each { |value| deep_freeze(value) }
              end

              object.freeze
            end
          end
        end
      end
    end
  end
end
