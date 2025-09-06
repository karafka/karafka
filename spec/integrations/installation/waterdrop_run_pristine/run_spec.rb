# frozen_string_literal: true

# WaterDrop should work without any extra require or anything and without Rails

# @see https://github.com/karafka/waterdrop/pull/485

require 'waterdrop'
require_relative '../../support/kafka_helper'

producer = WaterDrop::Producer.new

producer.setup do |config|
  config.deliver = true
  config.kafka = {
    'bootstrap.servers': kafka_bootstrap_servers,
    'request.required.acks': 1
  }
end

producer.close
