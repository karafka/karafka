# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class ActiveJob < Base
        # This feature validation contracts
        module Contracts
          # Rules around using ActiveJob routing - basically you need to have ActiveJob available
          # in order to be able to use active job routing
          class Topic < Karafka::Contracts::Base
            configure do |config|
              config.error_messages = YAML.safe_load(
                File.read(
                  File.join(Karafka.gem_root, 'config', 'locales', 'errors.yml')
                )
              ).fetch('en').fetch('validations').fetch('topic')
            end

            virtual do |data, errors|
              next unless errors.empty?
              next unless data[:active_job][:active]
              # One should not define active job jobs without ActiveJob being available for usage
              next if Object.const_defined?('ActiveJob::Base')

              [[%i[consumer], :active_job_missing]]
            end

            # ActiveJob needs to always run with manual offset management
            # Automatic offset management cannot work with ActiveJob. Otherwise we could mark as
            # consumed jobs that did not run because of shutdown.
            virtual do |data, errors|
              next unless errors.empty?
              next unless data[:active_job][:active]
              next if data[:manual_offset_management][:active]

              [[%i[manual_offset_management], :must_be_enabled]]
            end
          end
        end
      end
    end
  end
end
