# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class ActiveJob < Base
        # Config for ActiveJob usage
        Config = BaseConfig.define(:active) { alias_method :active?, :active }
      end
    end
  end
end
