# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Deserializers < Base
        # Config of this feature
        Config = BaseConfig.define(
          :active,
          :payload,
          :key,
          :headers
        ) { alias_method :active?, :active }
      end
    end
  end
end
