# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
