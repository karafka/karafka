# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    # This feature allows for proxying messages via a special topic that can dispatch them
    # at a later time, hence scheduled messages. Such messages need to have a special format
    # but aside from that they are regular Kafka messages.
    #
    # This work was conceptually inspired by the Go scheduler:
    # https://github.com/etf1/kafka-message-scheduler though I did not look at the implementation
    # itself. Just the concept of daily in-memory scheduling.
    module ScheduledMessages
      # Version of the schema we use for envelops in scheduled messages.
      # We use it to detect any potential upgrades similar to other components of Karafka and to
      # stop processing of incompatible versions
      SCHEMA_VERSION = '1.0.0'

      # Version of the states schema. Used to publish per partition simple aggregated metrics
      # that can be used for schedules reporting
      STATES_SCHEMA_VERSION = '1.0.0'

      class << self
        # Runs the `Proxy.call`
        # @param kwargs [Hash] things requested by the proxy
        # @return [Hash] message wrapped with the scheduled message envelope
        def schedule(**kwargs)
          Proxy.schedule(**kwargs)
        end

        # Generates a tombstone message to cancel given dispatch (if not yet happened)
        # @param kwargs [Hash] things requested by the proxy
        # @return [Hash] tombstone cancelling message
        def cancel(**kwargs)
          Proxy.cancel(**kwargs)
        end

        # Below are private APIs

        # Sets up additional config scope, validations and other things
        #
        # @param config [Karafka::Core::Configurable::Node] root node config
        def pre_setup(config)
          # Expand the config with this feature specific stuff
          config.instance_eval do
            setting(:scheduled_messages, default: Setup::Config.config)
          end
        end

        # @param config [Karafka::Core::Configurable::Node] root node config
        def post_setup(config)
          RecurringTasks::Contracts::Config.new.validate!(config.to_h)
        end
      end
    end
  end
end
