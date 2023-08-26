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
        # Small extension to make ActiveJob work with pattern matching.
        # Since our `#active_job_topic` is just a topic wrapper, we can introduce a similar
        # `#active_job_pattern` to align with pattern building
        class ActiveJob < Base
        end
      end
    end
  end
end
