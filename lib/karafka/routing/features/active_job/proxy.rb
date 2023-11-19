# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class ActiveJob < Base
        # Routing proxy extensions for ActiveJob
        module Proxy
          include Builder
        end
      end
    end
  end
end
