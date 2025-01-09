# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
