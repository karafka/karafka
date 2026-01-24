# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

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
        # @return [Hash] message wrapped with the scheduled message envelope
        def schedule(**)
          Proxy.schedule(**)
        end

        # Generates a tombstone message to cancel given dispatch (if not yet happened)
        # @return [Hash] tombstone cancelling message
        def cancel(**)
          Proxy.cancel(**)
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
          ScheduledMessages::Contracts::Config.new.validate!(
            config.to_h,
            scope: %w[config]
          )
        end

        # Basically since we may have custom producers configured that are not the same as the
        # default one, we hold a reference to old pre-fork producer. This means, that when we
        # initialize it again in post-fork, as long as user uses defaults we should re-inherit
        # it from the default config.
        #
        # @param config [Karafka::Core::Configurable::Node]
        # @param pre_fork_producer [WaterDrop::Producer]
        def post_fork(config, pre_fork_producer)
          return unless config.scheduled_messages.producer == pre_fork_producer

          config.scheduled_messages.producer = config.producer
        end
      end
    end
  end
end
