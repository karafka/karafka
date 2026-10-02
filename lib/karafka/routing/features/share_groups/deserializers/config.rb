# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      module ShareGroups
        class Deserializers < Base
          # Config of this feature
          Config = Struct.new(
            :active,
            :payload,
            :key,
            :headers,
            keyword_init: true
          ) { alias_method :active?, :active }
        end
      end
    end
  end
end
