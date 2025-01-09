# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        # This feature allows you to run recurring tasks aka cron jobs from within Karafka
        # It uses two special topics for tracking the schedule and reporting executions
        class RecurringTasks < Base
        end
      end
    end
  end
end
