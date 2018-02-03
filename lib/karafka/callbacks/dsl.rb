# frozen_string_literal: true

module Karafka
  module Callbacks
    # App level dsl to define callbacks
    module Dsl
      Callbacks::TYPES.each do |callback_type|
        # Allows us to define a block, that will be executed for a given moment
        # @param [Block] block that should be executed after the initialization process
        define_method callback_type do |&block|
          config.callbacks.send(callback_type).push block
        end
      end
    end
  end
end
