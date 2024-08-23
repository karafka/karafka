# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Eofed < Base
        # Eofed related contracts namespace
        module Contracts
          # Contract for eofed topic setup
          class Topic < Karafka::Contracts::Base
            configure do |config|
              config.error_messages = YAML.safe_load(
                File.read(
                  File.join(Karafka.gem_root, 'config', 'locales', 'errors.yml')
                )
              ).fetch('en').fetch('validations').fetch('topic')
            end

            nested :eofed do
              required(:active) { |val| [true, false].include?(val) }
            end

            virtual do |data, errors|
              next unless errors.empty?

              eofed = data[:eofed]

              next unless eofed[:active]

              next if data[:kafka][:'enable.partition.eof']

              [[%i[eofed kafka], :enable]]
            end
          end
        end
      end
    end
  end
end
