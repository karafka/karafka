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
        class AdaptiveIterator < Base
          # Namespace for adaptive iterator contracts
          module Contracts
            # Contract to validate configuration of the adaptive iterator feature
            class Topic < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load(
                  File.read(
                    File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                  )
                ).fetch('en').fetch('validations').fetch('topic')
              end

              nested(:adaptive_iterator) do
                required(:active) { |val| [true, false].include?(val) }
                required(:safety_margin) { |val| val.is_a?(Integer) && val.positive? && val < 100 }
                required(:adaptive_margin) { |val| [true, false].include?(val) }
                required(:mark_after_yielding) { |val| [true, false].include?(val) }
                required(:clean_after_yielding) { |val| [true, false].include?(val) }

                required(:marking_method) do |val|
                  %i[mark_as_consumed mark_as_consumed!].include?(val)
                end
              end
            end
          end
        end
      end
    end
  end
end
