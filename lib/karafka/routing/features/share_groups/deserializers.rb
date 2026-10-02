# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      module ShareGroups
        # Namespace for feature allowing to configure deserializers for payload, key and headers.
        # Mirrors {Features::ConsumerGroups::Deserializers} - share groups process message payloads,
        # keys and headers just like consumer groups.
        class Deserializers < Base
        end
      end
    end
  end
end
