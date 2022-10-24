# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      # All the things needed to be able to manage manual offset management from the routing
      # perspective.
      #
      # Manual offset management allows users to completely disable automatic management of the
      # offset. This can be used for implementing long-living window operations and other things
      # where we do not want to commit the offset with each batch.
      #
      # Not all the Karafka and Karafka Pro features may be compatible with this feature being on.
      class ManualOffsetManagement < Base
      end
    end
  end
end
