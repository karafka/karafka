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
        class VirtualPartitions < Base
          # Namespace for VP contracts
          module Contracts
            # Rules around virtual partitions
            class Topic < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load_file(
                  File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                ).fetch('en').fetch('validations').fetch('routing').fetch('topic')
              end

              nested(:virtual_partitions) do
                required(:active) { |val| [true, false].include?(val) }
                required(:partitioner) { |val| val.nil? || val.respond_to?(:call) }
                required(:reducer) { |val| val.respond_to?(:call) }
                required(:max_partitions) { |val| val.is_a?(Integer) && val >= 1 }
                required(:offset_metadata_strategy) { |val| %i[exact current].include?(val) }
                required(:distribution) { |val| %i[consistent balanced].include?(val) }
              end

              # When virtual partitions are defined, partitioner needs to respond to `#call` and it
              # cannot be nil
              virtual do |data, errors|
                next unless errors.empty?

                virtual_partitions = data[:virtual_partitions]

                next unless virtual_partitions[:active]
                next if virtual_partitions[:partitioner].respond_to?(:call)

                [[%i[virtual_partitions partitioner], :respond_to_call]]
              end
            end
          end
        end
      end
    end
  end
end
