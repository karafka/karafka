# frozen_string_literal: true

# This Karafka component is a Pro component.
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

module Karafka
  module Pro
    module Routing
      module Features
        class LongRunningJob < Karafka::Routing::Features::Base
          # Long-Running Jobs configuration
          Config = Struct.new(
            :active,
            keyword_init: true
          ) { alias_method :active?, :active }
        end
      end
    end
  end
end