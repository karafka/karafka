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
          class Estimator
            # Builds the estimation result out of the per-batch stats of each partition. It
            # aggregates the stats per partition and for all of them together, scores them and
            # returns a deeply frozen Hash.
            class ResultBuilder
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

              # @param settings [Hash] estimator settings to include in the result. Its
              #   `:concurrency` is used to count the poor batches.
              # @param details [Boolean] should the partitions stats also include per-batch details
              def initialize(settings:, details:)
                @settings = settings
                @concurrency = settings.fetch(:concurrency)
                @details = details
              end

              # @param topic_name [String, nil] name of the topic. It is copied, so the given
              #   String is not frozen.
              # @param partitions_batches [Hash{Integer => Array<Hash>}] batches stats per partition
              # @return [Hash] frozen estimation result
              def call(topic_name, partitions_batches)
                all_batches = []

                partitions = partitions_batches.sort.to_h do |partition, batches|
                  all_batches.concat(batches)

                  [partition, aggregate(batches)]
                end

                deep_freeze(
                  format_version: FORMAT_VERSION,
                  topic_name: topic_name.dup,
                  settings: @settings.dup,
                  partitions: partitions,
                  summary: aggregate(all_batches, details: false)
                )
              end

              private

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
end
