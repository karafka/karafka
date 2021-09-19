# frozen_string_literal: true

module Karafka
  module Messages
    # "Fake" message that we use as an abstraction layer when seeking back.
    # This allows us to encapsulate a seek with a simple abstraction
    Seek = Struct.new(:topic, :partition, :offset)
  end
end
