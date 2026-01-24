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
        class Patterns < Base
          module Contracts
            # Contract to validate configuration of the filtering feature
            class ConsumerGroup < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load_file(
                  File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                ).fetch('en').fetch('validations').fetch('routing').fetch('consumer_group')

                required(:patterns) { |val| val.is_a?(Array) && val.all?(Hash) }

                virtual do |data, errors|
                  next unless errors.empty?

                  validator = Pattern.new

                  data[:patterns].each do |pattern|
                    validator.validate!(pattern)
                  end

                  nil
                end

                # Make sure, that there are no same regular expressions with different names
                # in a single consumer group
                virtual do |data, errors|
                  next unless errors.empty?

                  regexp_strings = data[:patterns].map { |pattern| pattern.fetch(:regexp_string) }
                  regexp_names = data[:patterns].map { |pattern| pattern.fetch(:name) }

                  # If all names are the same for the same regexp, it means its a multiplex and
                  # we can allow it
                  next if regexp_names.uniq.size == 1 && regexp_strings.uniq.size == 1
                  next if regexp_strings.empty?
                  next if regexp_strings.uniq.size == regexp_strings.size

                  [[%i[patterns], :regexps_not_unique]]
                end
              end
            end
          end
        end
      end
    end
  end
end
