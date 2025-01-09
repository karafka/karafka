# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka in a PORO project should load without any problems

require 'karafka'

class KarafkaApp < Karafka::App
  setup do |config|
    config.kafka = { 'bootstrap.servers': 'host:9092' }
  end

  routes.draw do
    topic :visits do
      consumer Class.new(Karafka::BaseConsumer)
      long_running_job
    end
  end
end
