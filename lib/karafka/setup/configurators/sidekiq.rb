module Karafka
  module Setup
    class Configurators
      # Class to configure all the Sidekiq settings based on Karafka settings
      class Sidekiq < Base
        # Sets up sidekiq client and server
        def setup
          setup_sidekiq_client
          setup_sidekiq_server
        end

        private

        # Configure sidekiq client
        def setup_sidekiq_client
          ::Sidekiq.configure_client do |sidekiq_config|
            sidekiq_config.redis = config.redis.to_h.merge(
              size: config.max_concurrency
            )
          end
        end

        # Configure sidekiq setorrver
        def setup_sidekiq_server
          ::Sidekiq.configure_server do |sidekiq_config|
            # We don't set size for the server - this will be set automatically based
            # on the Sidekiq concurrency level (Sidekiq not Karafkas)
            sidekiq_config.redis = config.redis.to_h
          end
        end
      end
    end
  end
end
