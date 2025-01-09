# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to use a license encrypted token as a setup source for Karafka and it
# should work as described in the integration docs

module Karafka
  module License
    class << self
      def token
        ENV.fetch('KARAFKA_PRO_LICENSE_TOKEN')
      end
    end
  end
end

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
