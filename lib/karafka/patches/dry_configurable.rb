module Karafka
  # Namespace for patches of external gems/libraries
  module Patches
    # Patch that will allow to use proc based lazy evaluated settings with Dry Configurable
    # @see https://github.com/dry-rb/dry-configurable/blob/master/lib/dry/configurable.rb
    module DryConfigurable
      # We overwrite ::Dry::Configurable::Config to change on proc behaviour
      # Unfortunately it does not provide an on call proc evaluation, so
      # this feature had to be added here on demand/
      # @param args Any arguments that DryConfigurable::Config accepts
      def initialize(*args)
        super

        @config.each do |key, _value|
          rebuild(key)
        end
      end

      private

      # Method that rebuilds a given accessor, so when it consists a proc value, it will
      # evaluate it upon return
      # @param method_name [Symbol] name of an accessor that we want to rebuild
      def rebuild(method_name)
        define_singleton_method method_name do
          super().is_a?(Proc) ? super().call : super()
        end
      end
    end
  end
end

::Dry::Configurable::Config.prepend(Karafka::Patches::DryConfigurable)
