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
    module Processing
      module Strategies
        # Namespace for ActiveJob related strategies
        module Aj
          # ActiveJob enabled
          # Manual Offset management enabled
          module Mom
            # Standard ActiveJob strategy is the same one we use for Mom
            include Strategies::Mom::Default

            # Features for this strategy
            FEATURES = %i[
              active_job
              manual_offset_management
            ].freeze
          end
        end
      end
    end
  end
end
