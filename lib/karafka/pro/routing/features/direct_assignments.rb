# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        # Allows for building direct assignments that bypass consumer group auto-assignments
        # Useful for building complex pipelines that have explicit assignment requirements
        class DirectAssignments < Base
        end
      end
    end
  end
end
