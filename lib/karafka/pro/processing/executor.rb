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
    module Processing
      # Pro executor that supports periodic jobs
      class Executor < Karafka::Processing::Executor
        # Runs the code that should happen before periodic job is scheduled
        #
        # @note While jobs are called `Periodic`, from the consumer perspective it is "ticking".
        #   This name was taken for a reason: we may want to introduce periodic ticking also not
        #   only during polling but for example on wait and a name "poll" would not align well.
        #   A name "periodic" is not a verb and our other consumer actions are verbs like:
        #   consume or revoked. So for the sake of consistency we have ticking here.
        def before_schedule_periodic
          consumer.on_before_schedule_tick
        end

        # Triggers consumer ticking
        def periodic
          consumer.on_tick
        end
      end
    end
  end
end
