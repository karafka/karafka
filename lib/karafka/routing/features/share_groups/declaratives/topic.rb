# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      module ShareGroups
        class Declaratives < Base
          # Share-group topics use the same routing bridge as consumer-group topics
          Topic = ConsumerGroups::Declaratives::Topic
        end
      end
    end
  end
end
