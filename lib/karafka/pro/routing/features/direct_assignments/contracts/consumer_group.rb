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
