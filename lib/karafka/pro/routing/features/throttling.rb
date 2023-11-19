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
