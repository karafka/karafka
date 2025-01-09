# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class Filtering < Base
          # Namespace for filtering feature contracts
          module Contracts
            # Contract to validate configuration of the filtering feature
            class Topic < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load(
                  File.read(
                    File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                  )
                ).fetch('en').fetch('validations').fetch('topic')
              end

              nested(:filtering) do
                required(:active) { |val| [true, false].include?(val) }

                required(:factories) do |val|
                  val.is_a?(Array) && val.all? { |factory| factory.respond_to?(:call) }
                end
              end
            end
          end
        end
      end
    end
  end
end
