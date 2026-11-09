# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      module ShareGroups
        class Declaratives < Base
          # Share-group topics are validated with the same contracts as consumer-group topics
          Contracts = ConsumerGroups::Declaratives::Contracts
        end
      end
    end
  end
end
