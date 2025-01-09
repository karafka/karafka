# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class NonBlockingJob < Base
          # Non-Blocking Jobs topic API extensions
          module Topic
            # @param args [Array] anything accepted by the `#long_running_job` API
            def non_blocking_job(*args)
              long_running_job(*args)
            end

            alias non_blocking non_blocking_job
          end
        end
      end
    end
  end
end
