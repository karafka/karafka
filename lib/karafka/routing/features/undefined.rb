module Karafka
  module Routing
    module Features
      Undefined = Object.new.tap do |undefined|
        def undefined.to_s
          "undefined"
        end

        def undefined.inspect
          "undefined"
        end
      end
    end
  end
end
