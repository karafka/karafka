# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class LongRunningJob < Base
          # Namespace for LRJ contracts
          module Contracts
            # Rules around long-running job settings
            class Topic < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load_file(
                  File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                ).fetch('en').fetch('validations').fetch('routing').fetch('topic')
              end

              nested(:long_running_job) do
                required(:active) { |val| [true, false].include?(val) }
              end
            end
          end
        end
      end
    end
  end
end
