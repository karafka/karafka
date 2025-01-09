# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class Delaying < Base
          # Delaying feature configuration
          Config = Struct.new(:active, :delay, keyword_init: true) do
            alias_method :active?, :active
          end
        end
      end
    end
  end
end
