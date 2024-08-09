# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      # Namespace for feature allowing to enable the `#eofed` jobs.
      # We do not enable it always because users may only be interested in fast eofed yielding
      # without running the `#eofed` operation at all. This safes on empty cycles of running
      # pointless empty jobs.
      class Eofed < Base
      end
    end
  end
end
