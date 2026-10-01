# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      module ShareGroups
        # This feature allows to continue processing when encountering errors. Records that keep
        # failing are moved to an alternative topic after a number of deliveries, instead of being
        # dropped by the broker once the share group delivery count limit is reached. Mirrors
        # {Features::ConsumerGroups::DeadLetterQueue}.
        class DeadLetterQueue < Base
        end
      end
    end
  end
end
