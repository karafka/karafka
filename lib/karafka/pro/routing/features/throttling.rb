# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        # Ability to throttle ingestion of data per topic partition
        # Useful when we have fixed limit of things we can process in a given time period without
        # getting into trouble. It can be used for example to:
        #   - make sure we do not insert things to DB too fast
        #   - make sure we do not dispatch HTTP requests to external resources too fast
        #
        # This feature is virtual. It materializes itself via the `Filtering` feature.
        class Throttling < Base
        end
      end
    end
  end
end
