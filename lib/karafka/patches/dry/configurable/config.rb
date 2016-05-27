# Patch that will allow to use proc based lazy evaluated settings with Dry Configurable
# @see https://github.com/dry-rb/dry-configurable/blob/master/lib/dry/configurable.rb
module Dry
  # Configurable module for Dry-Configurable
  module Configurable
    # Config node instance struct
    class Config
      # @param args [Array] All arguments that a Struct accepts
      def initialize(*args)
        super
        setup_dynamics
      end

      private

      # Method that sets up all the proc based lazy evaluated dynamic config values
      def setup_dynamics
        each_pair do |key, value|
          next unless value.is_a?(Proc)

          rebuild(key)
        end
      end

      # Method that rebuilds a given accessor, so when it consists a proc value, it will
      # evaluate it upon return
      # @param method_name [Symbol] name of an accessor that we want to rebuild
      def rebuild(method_name)
        metaclass = class << self; self; end

        metaclass.send(:define_method, method_name) do
          super().is_a?(Proc) ? super().call : super()
        end
      end
    end
  end
end
