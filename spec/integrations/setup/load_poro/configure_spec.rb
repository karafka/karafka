# frozen_string_literal: true

# Karafka in a PORO project should load without any problems when regular (not pro)

require 'karafka'

class KarafkaApp < Karafka::App
  setup

  routes.draw do
    topic :visits do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
end
