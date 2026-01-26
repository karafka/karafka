# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# We should be able to use testing with multiplexing without any exceptions

setup_karafka
setup_testing(:rspec)

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << true
  end
end

draw_routes do
  subscription_group :test do
    multiplexing(max: 2)

    topic DT.topic do
      consumer Consumer
    end
  end
end

RSpec.describe Consumer do
  subject(:consumer) { karafka.consumer_for(DT.topic) }

  before { karafka.produce("test") }

  it "expects to increase count" do
    expect { consumer.consume }.to change(DT[0], :count).by(1)
  end
end
