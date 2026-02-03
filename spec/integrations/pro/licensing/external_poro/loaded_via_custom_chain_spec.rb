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

# We should be able to use a license encrypted token as a setup source for Karafka and it
# should work as described in the integration docs

module Karafka
  module License
    class << self
      def token
        ENV.fetch("KARAFKA_PRO_LICENSE_TOKEN")
      end

      def version
        ENV.fetch("KARAFKA_PRO_VERSION", "")
      end
    end
  end
end

require "karafka"

class KarafkaApp < Karafka::App
  setup do |config|
    config.kafka = { "bootstrap.servers": "host:9092" }
  end

  routes.draw do
    topic :visits do
      consumer Class.new(Karafka::BaseConsumer)
      long_running_job
    end
  end
end

raise unless Karafka.pro?

# None of this should fail as all should be visible
raise unless Karafka::Pro::Processing::StrategySelector
raise unless Karafka::Pro::Processing::Coordinator
raise unless Karafka::Pro::Processing::Partitioner
raise unless Karafka::BaseConsumer
raise unless Karafka::Pro::Processing::JobsBuilder
raise unless Karafka::Pro::Processing::Schedulers::Default
raise unless Karafka::Pro::Routing::Features::LongRunningJob::Topic
raise unless Karafka::Pro::Routing::Features::LongRunningJob::Contracts
raise unless Karafka::Pro::Routing::Features::LongRunningJob::Config
raise unless Karafka::Pro::Routing::Features::VirtualPartitions::Topic
raise unless Karafka::Pro::Routing::Features::VirtualPartitions::Contracts
raise unless Karafka::Pro::Routing::Features::VirtualPartitions::Config
raise unless Karafka::Pro::Processing::Jobs::ConsumeNonBlocking
raise unless Karafka::Pro::ActiveJob::Consumer
raise unless Karafka::Pro::ActiveJob::Dispatcher
raise unless Karafka::Pro::ActiveJob::JobOptionsContract
raise unless Karafka::Pro::Instrumentation::PerformanceTracker
