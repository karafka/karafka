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

# When we start from too many connections, we should effectively go down and establish baseline

setup_karafka do |config|
  c_klass = config.internal.connection.conductor.class

  config.internal.connection.conductor = c_klass.new(1_000)
  config.concurrency = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
  end
end

draw_routes do
  subscription_group :sg do
    multiplexing(max: 5, min: 1, boot: 5, scale_delay: 1_000)

    topic DT.topic do
      config(partitions: 2)
      consumer Consumer
    end
  end
end

done = false

# No specs needed, will hang if not scaling correctly
start_karafka_and_wait_until do
  if Karafka::Server.listeners.count(&:active?) == 2
    sleep(10)

    done = true
  end

  done
end
