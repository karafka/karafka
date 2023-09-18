# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class InlineInsights < Base
        Config = Struct.new(
          :active,
          keyword_init: true
        ) { alias_method :active?, :active }
      end
    end
  end
end
