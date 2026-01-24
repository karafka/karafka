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
    module ScheduledMessages
      # Represents the loading/bootstrapping state of the given topic partition
      #
      # Bootstrapping can be in the following states:
      # - fresh - when we got an assignment but we did not load the schedule yet
      # - loading - when we are in the process of bootstrapping the daily state and we consume
      #   historical messages to build the needed schedules.
      # - loaded - state in which we finished loading all the schedules and we can dispatch
      #   messages when the time comes and we can process real-time incoming schedules and
      #   changes to schedules as they appear in the stream.
      # - shutdown - the states are no longer available as the consumer has shut down
      class State
        # Available states scheduling of messages may be in
        STATES = %w[
          fresh
          loading
          loaded
          stopped
        ].freeze

        private_constant :STATES

        # Initializes the state as fresh
        def initialize
          @state = 'fresh'
        end

        STATES.each do |state|
          define_method :"#{state}!" do
            @state = state
          end

          define_method :"#{state}?" do
            @state == state
          end
        end

        # @return [String] current state string representation
        def to_s
          @state
        end
      end
    end
  end
end
