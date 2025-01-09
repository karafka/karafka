# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class Patterns < Base
          module Contracts
            # Contract to validate configuration of the filtering feature
            class ConsumerGroup < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load(
                  File.read(
                    File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                  )
                ).fetch('en').fetch('validations').fetch('consumer_group')

                required(:patterns) { |val| val.is_a?(Array) && val.all? { |el| el.is_a?(Hash) } }

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
