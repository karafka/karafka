# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class ManualOffsetManagement < Base
        # Config for manual offset management feature
        Config = Struct.new(
          :active,
          keyword_init: true
        ) { alias_method :active?, :active }
      end
    end
  end
end
