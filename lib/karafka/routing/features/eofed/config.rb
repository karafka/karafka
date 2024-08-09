# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Eofed < Base
        # Config of this feature
        Config = Struct.new(
          :active,
          keyword_init: true
        ) { alias_method :active?, :active }
      end
    end
  end
end
