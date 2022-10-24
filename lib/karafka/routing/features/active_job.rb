# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      # Active-Job related components
      # @note We can load it always, despite someone not using ActiveJob as it just adds a method
      #   to the routing, without actually breaking anything.
      class ActiveJob < Base
      end
    end
  end
end
