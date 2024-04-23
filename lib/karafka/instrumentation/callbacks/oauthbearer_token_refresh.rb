# frozen_string_literal: true

module Karafka
  module Instrumentation
    module Callbacks
      # Callback that is triggered when oauth token needs to be refreshed.
      class OauthbearerTokenRefresh
        include Helpers::ConfigImporter.new(
          monitor: %i[monitor]
        )

        # @param bearer [Rdkafka::Consumer, Rdkafka::Admin] given rdkafka instance. It is needed as
        #   we need to have a reference to call `#oauthbearer_set_token` or
        #   `#oauthbearer_set_token_failure` upon the event.
        def initialize(bearer)
          @bearer = bearer
        end

        # @param _rd_config [Rdkafka::Config]
        # @param bearer_name [String] name of the bearer for which we refresh
        def call(_rd_config, bearer_name)
          return unless @bearer.name == bearer_name

          monitor.instrument(
            'oauthbearer.token_refresh',
            bearer: @bearer,
            caller: self
          )
        rescue StandardError => e
          monitor.instrument(
            'error.occurred',
            caller: self,
            type: 'callbacks.oauthbearer_token_refresh.error',
            error: e
          )
        end
      end
    end
  end
end
