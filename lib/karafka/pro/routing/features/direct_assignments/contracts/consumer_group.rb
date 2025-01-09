# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class DirectAssignments < Base
          module Contracts
            # Contract to validate configuration of the direct assignments feature
            class ConsumerGroup < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load(
                  File.read(
                    File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                  )
                ).fetch('en').fetch('validations').fetch('consumer_group')

                virtual do |data, errors|
                  next unless errors.empty?

                  active = []

                  data[:topics].each do |topic|
                    active << topic[:direct_assignments][:active]
                  end

                  # If none active we use standard subscriptions
                  next if active.none?
                  # If all topics from a given CG are using direct assignments that is expected
                  # and allowed
                  next if active.all?

                  [[%i[direct_assignments], :homogenous]]
                end
              end
            end
          end
        end
      end
    end
  end
end
