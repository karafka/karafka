# frozen_string_literal: true

# Karafka in a PORO project should load without any problems

require 'karafka'

class KarafkaApp < Karafka::App
  setup do |config|
    config.license.token = ENV.fetch('KARAFKA_PRO_LICENSE_TOKEN')
  end

  routes.draw do
    topic :visits do
      consumer Class.new(Karafka::Pro::BaseConsumer)
    end
  end
end
