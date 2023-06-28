# frozen_string_literal: true

module Karafka
  module Messages
    # "Fake" message that we use as an abstraction layer when seeking back.
    # This allows us to encapsulate a seek with a simple abstraction
    #
    # @note `#offset` can be either the offset value or the time of the offset
    # (first equal or greater)
    Seek = Struct.new(:topic, :partition, :offset)
  end
end
