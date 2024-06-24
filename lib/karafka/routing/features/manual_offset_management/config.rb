# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class ManualOffsetManagement < Base
        # Config for manual offset management feature
        Config = BaseConfig.define(:active) { alias_method :active?, :active }
      end
    end
  end
end
