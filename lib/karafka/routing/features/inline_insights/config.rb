# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class InlineInsights < Base
        # Config of this feature
        Config = BaseConfig.define(
          :active
        ) { alias_method :active?, :active }
      end
    end
  end
end
