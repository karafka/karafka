# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class RecurringTasks < Base
          # Routing proxy extensions for recurring tasks
          module Proxy
            include Builder
          end
        end
      end
    end
  end
end
