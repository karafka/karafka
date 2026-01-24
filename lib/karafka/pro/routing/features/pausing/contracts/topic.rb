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
        class Pausing < Base
          # Namespace for pausing feature
          module Contracts
            # Contract to make sure, that the pause settings on a per topic basis are as expected
            class Topic < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load_file(
                  File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                ).fetch('en').fetch('validations').fetch('routing').fetch('topic')

                # Validate the nested pausing configuration
                # Both old setters and new pause() method update the pausing config,
                # so we only need to validate this one format
                nested :pausing do
                  required(:active) { |val| [true, false].include?(val) }
                  required(:timeout) { |val| val.is_a?(Integer) && val.positive? }
                  required(:max_timeout) { |val| val.is_a?(Integer) && val.positive? }
                  required(:with_exponential_backoff) { |val| [true, false].include?(val) }
                end

                # Validate that timeout <= max_timeout
                virtual do |data, errors|
                  next unless errors.empty?

                  pausing = data.fetch(:pausing)
                  timeout = pausing.fetch(:timeout)
                  max_timeout = pausing.fetch(:max_timeout)

                  next if timeout <= max_timeout

                  [[%i[pausing timeout], :max_timeout_vs_pause_max_timeout]]
                end
              end
            end
          end
        end
      end
    end
  end
end
