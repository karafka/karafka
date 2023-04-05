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
        # Delaying allows us to delay processing of certain topics. This is useful when we want
        # to for any reason to wait until processing data from a topic. It does not sleep and
        # instead uses pausing to manage delays. This allows us to free up processing resources
        # and not block the polling thread.
        #
        # Delaying is a virtual feature realized via the filters
        class Delaying < Base
        end
      end
    end
  end
end
