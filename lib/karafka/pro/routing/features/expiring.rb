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
        # Expiring allows us to filter out messages that are older than our expectation.
        # This can also be done in a consumer, but applying the filtering prior to the jobs
        # enqueuing allows us to improve operations with virtual partitions and limit the number of
        # not necessary messages being ever seen
        class Expiring < Base
        end
      end
    end
  end
end
