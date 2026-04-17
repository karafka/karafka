# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# Pro components should be loaded when we run in pro mode and a nice message should be printed

LOGS = StringIO.new

setup_karafka do |config|
  config.logger = Logger.new(LOGS)
end

LOGS.rewind

logs = LOGS.read
config = Karafka::App.config.internal
pro = Karafka::Pro

assert_equal false, logs.include?("] ERROR -- : Your license expired")
assert_equal false, logs.include?("Please reach us")
assert Karafka.pro?
assert const_visible?("Karafka::Pro::Processing::ConsumerGroups::StrategySelector")
assert const_visible?("Karafka::Pro::Processing::ConsumerGroups::Coordinator")
assert const_visible?("Karafka::Pro::Processing::ConsumerGroups::Partitioner")
assert const_visible?("Karafka::BaseConsumer")
assert const_visible?("Karafka::Pro::Processing::JobsBuilder")
assert const_visible?("Karafka::Pro::Processing::Schedulers::Default")
assert const_visible?("Karafka::Pro::Routing::Features::LongRunningJob::Topic")
assert const_visible?("Karafka::Pro::Routing::Features::LongRunningJob::Contracts")
assert const_visible?("Karafka::Pro::Routing::Features::LongRunningJob::Config")
assert const_visible?("Karafka::Pro::Routing::Features::VirtualPartitions::Topic")
assert const_visible?("Karafka::Pro::Routing::Features::VirtualPartitions::Contracts")
assert const_visible?("Karafka::Pro::Routing::Features::VirtualPartitions::Config")
assert const_visible?("Karafka::Pro::Processing::ConsumerGroups::Jobs::ConsumeNonBlocking")
assert const_visible?("Karafka::Pro::ActiveJob::Consumer")
assert const_visible?("Karafka::Pro::ActiveJob::Dispatcher")
assert const_visible?("Karafka::Pro::ActiveJob::JobOptionsContract")
assert const_visible?("Karafka::Pro::Instrumentation::PerformanceTracker")
assert_equal pro::Processing::ConsumerGroups::StrategySelector, config.processing.consumer_groups.strategy_selector.class
assert_equal pro::Processing::ConsumerGroups::Partitioner, config.processing.consumer_groups.partitioner_class
assert_equal pro::Processing::ConsumerGroups::Coordinator, config.processing.consumer_groups.coordinator_class
assert_equal pro::Processing::Schedulers::Default, config.processing.scheduler_class
assert_equal pro::Processing::JobsQueue, config.processing.jobs_queue_class
assert_equal pro::Processing::JobsBuilder, config.processing.consumer_groups.jobs_builder.class
assert_equal pro::ActiveJob::Dispatcher, config.active_job.dispatcher.class
assert_equal pro::ActiveJob::Consumer, config.active_job.consumer_class
assert_equal pro::ActiveJob::JobOptionsContract, config.active_job.job_options_contract.class
# With encryption disabled, normal parser should be used
parser = Karafka::Messages::Parser
assert Karafka::App.config.internal.messages.parser.is_a?(parser)
