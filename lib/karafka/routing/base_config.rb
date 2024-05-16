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
        Class.new(BaseConfig) do
          args.each do |field|
            define_method(field) do
              @configs[field]
            end
            # Defaults only get used in the constructor. Assigning a default indicates that no
            # value was passed into the method in question, meaning we actually should do nothing
            # in this case.
            define_method("#{field}=") do |v|
              unless v.is_a?(Default)
                @configs[field] = v
              end
            end
          end
          module_exec(&block) if block
        end

      end
    end

  end
end
