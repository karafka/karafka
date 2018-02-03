# frozen_string_literal: true

module Karafka
  module Callbacks
    # Additional configuration required to store procs that we will execute upon callback trigger
    module Config
      # Builds up internal callback accumulators
      # @param klass [Class] Class that we extend with callback config
      def self.extended(klass)
        # option internal [Hash] - optional - internal karafka configuration settings that should
        #   never be changed by users directly
        klass.setting :callbacks do
          Callbacks::TYPES.each do |callback_type|
            # option [Array<Proc>] an array of blocks that will be executed at a given moment
            #   depending on the callback type
            setting callback_type, []
          end
        end
      end
    end
  end
end
