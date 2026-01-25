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
    module Routing
      module Features
        class ParallelSegments < Base
          # Namespace for parallel segments contracts
          module Contracts
            # Contract to validate configuration of the parallel segments feature
            class ConsumerGroup < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load_file(
                  File.join(Karafka.gem_root, "config", "locales", "pro_errors.yml")
                ).fetch("en").fetch("validations").fetch("routing").fetch("consumer_group")

                nested(:parallel_segments) do
                  required(:active) { |val| [true, false].include?(val) }
                  required(:partitioner) { |val| val.nil? || val.respond_to?(:call) }
                  required(:reducer) { |val| val.respond_to?(:call) }
                  required(:count) { |val| val.is_a?(Integer) && val >= 1 }
                  required(:merge_key) { |val| val.is_a?(String) && val.size >= 1 }
                end

                # When parallel segments are defined, partitioner needs to respond to `#call` and
                # it cannot be nil
                virtual do |data, errors|
                  next unless errors.empty?

                  parallel_segments = data[:parallel_segments]

                  next unless parallel_segments[:active]
                  next if parallel_segments[:partitioner].respond_to?(:call)

                  [[%i[parallel_segments partitioner], :respond_to_call]]
                end
              end
            end
          end
        end
      end
    end
  end
end
