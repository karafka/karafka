# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

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
