# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

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
