# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        # Small extension to make ActiveJob work with pattern matching.
        # Since our `#active_job_topic` is just a topic wrapper, we can introduce a similar
        # `#active_job_pattern` to align with pattern building
        class ActiveJob < Base
        end
      end
    end
  end
end
