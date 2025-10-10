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
            # Non blocking setting method
            def non_blocking_job(*)
              long_running_job(*)
            end

            alias non_blocking non_blocking_job
          end
        end
      end
    end
  end
end
