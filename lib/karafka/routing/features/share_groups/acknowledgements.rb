# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      module ShareGroups
        # Feature allowing to configure what happens with records that the consumer did not
        # acknowledge itself once a batch was processed successfully. Records left unacknowledged
        # after a failure are always released for redelivery.
        class Acknowledgements < Base
        end
      end
    end
  end
end
