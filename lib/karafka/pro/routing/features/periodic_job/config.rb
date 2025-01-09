# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class PeriodicJob < Base
          # Config for periodics topics feature
          Config = Struct.new(
            :active,
            :during_pause,
            :during_retry,
            :interval,
            :materialized,
            keyword_init: true
          ) do
            alias_method :active?, :active
            alias_method :during_pause?, :during_pause
            alias_method :during_retry?, :during_retry
            alias_method :materialized?, :materialized
          end
        end
      end
    end
  end
end
