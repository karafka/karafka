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
    module Routing
      module Features
        module ShareGroups
          class VirtualPartitions < Base
            # Topic extensions to be able to manage share-group virtual partitions
            module Topic
              # This method sets up the extra instance variable to nil before calling
              # the parent class initializer. The explicit initialization
              # to nil is included as an optimization for Ruby's object shapes system,
              # which improves memory layout and access performance.
              def initialize(...)
                @virtual_partitions = nil
                super
              end

              # @param max_partitions [Integer] max number of virtual partitions that can come out
              #   of the records of a single topic partition in a poll batch. Each of them is
              #   processed by its own consumer instance.
              # @param partitioner [nil, #call] nil or callable partitioner returning a key per
              #   record (records with the same key land in the same virtual partition). Use
              #   {Processing::ShareGroups::VirtualPartitions::Partitioners::RoundRobin} to spread
              #   records evenly.
              # @param reducer [nil, #call] reducer for the partitioner keys. It allows for using a
              #   custom reducer when the default one is not enough.
              # @param distribution [Symbol] `:consistent` or `:balanced` distribution of the
              #   records
              # @return [Config] virtual partitions config
              def virtual_partitions(
                max_partitions: Karafka::App.config.concurrency,
                partitioner: nil,
                reducer: nil,
                distribution: :consistent
              )
                @virtual_partitions ||= Config.new(
                  active: !partitioner.nil?,
                  max_partitions: max_partitions,
                  partitioner: partitioner,
                  # If no reducer provided, we use this one. Integer keys (like the round robin
                  # partitioner ones) are spread directly with a modulo, other keys use a modulo on
                  # the sum of a stringified version, providing fairly good distribution.
                  reducer: reducer || lambda { |virtual_key|
                    if virtual_key.is_a?(Integer)
                      virtual_key % max_partitions
                    else
                      virtual_key.to_s.sum % max_partitions
                    end
                  },
                  distribution: distribution
                )
              end

              # @return [Boolean] are virtual partitions enabled for given topic
              def virtual_partitions?
                virtual_partitions.active?
              end

              # @return [Hash] topic with all its native configuration options plus virtual
              #   partitions settings
              def to_h
                super.merge(
                  virtual_partitions: virtual_partitions.to_h
                ).freeze
              end
            end
          end
        end
      end
    end
  end
end
