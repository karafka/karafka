# frozen_string_literal: true

module Karafka
  module Setup
    class Configurators
      # Karafka::Params::Params are dynamically built based on user defined parent class
      # so we cannot just require it, we need to initialize it after user is done with
      # the framework configuration. This is a configurator that does exactly that.
      class Params < Base
        # Builds up Karafka::Params::Params class with user defined parent class
        # @param [Block] block configuration block
        def self.setup(config)
          Karafka::Params.const_set(
            'Params',
            Class
              .new(config.internals.params_base_class)
              .tap { |klass| klass.include(Karafka::Params::Dsl) }
          )
        end
      end
    end
  end
end
