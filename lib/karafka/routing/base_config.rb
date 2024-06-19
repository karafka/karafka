module Karafka
  module Routing

    class BaseConfig
      def self.all_defaults?(*args)
        args.all? { |a| a.is_a?(Default)}
      end

      def sanitize(v) = v.is_a?(Default) ? v.value : v

      def initialize(**kwargs)
        @configs = {}
        kwargs.each do |k, v|
          @configs[k] = sanitize(v)
        end
      end

      def to_h
        @configs
      end

      def [](val)
        @configs[val]
      end

      def self.define(*args, &block)
        klass = Class.new(BaseConfig)
        args.each do |field|

          # Defaults only get used in the constructor. Assigning a default indicates that no
          # value was passed into the method in question, meaning we actually should do nothing
          # in this case.
          klass.class_eval <<~METHODS, __FILE__, __LINE__ + 1
            def #{field} = @configs[:#{field}]
            def #{field}=(v)
              @configs[:#{field}] = v unless v.is_a?(Default)
            end
          METHODS
        end
        klass.class_exec(&block) if block
        klass
      end
    end

  end
end
