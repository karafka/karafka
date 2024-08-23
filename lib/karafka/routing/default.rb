module Karafka
  module Routing
    class Default
      attr_accessor :value
      def initialize(value=nil)
        self.value = value
      end
    end
  end
end
