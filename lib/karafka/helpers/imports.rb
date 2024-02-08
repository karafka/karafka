# frozen_string_literal: true

module Karafka
  module Helpers
    module Imports
      class Config < Module
        def initialize(attributes = { config: %i[itself] })
          @attributes = attributes
        end

        def included(model)
          super

          @attributes.each do |name, path|
            model.class_eval <<~RUBY, __FILE__, __LINE__ + 1
              def #{name}
                @#{name} ||= ::Karafka::App.config.#{path.join('.')}
              end
            RUBY
          end
        end
      end

      module Monitor
        def monitor
          @monitor ||= ::Karafka::App.config.monitor
        end
      end
    end
  end
end
