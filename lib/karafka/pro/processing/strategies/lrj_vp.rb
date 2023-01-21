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
        # Long-Running Job enabled
        # Virtual Partitions enabled
        module LrjVp
          # Same flow as the standard Lrj
          include Vp
          include Lrj

          # Features for this strategy
          FEATURES = %i[
            long_running_job
            virtual_partitions
          ].freeze
        end
      end
    end
  end
end
