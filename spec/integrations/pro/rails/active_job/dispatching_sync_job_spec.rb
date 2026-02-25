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

# Karafka should be able to dispatch jobs using sync pro adapter

setup_karafka

setup_active_job

draw_routes do
  active_job_topic DT.topic
end

class Job < ActiveJob::Base
  queue_as DT.topic

  karafka_options(
    dispatch_method: :produce_sync
  )

  def perform(value1, value2)
    DT[0] << value1
    DT[0] << value2
  end
end

VALUE1 = rand
VALUE2 = rand

Job.perform_later(VALUE1, VALUE2)

start_karafka_and_wait_until do
  DT.key?(0)
end

aj_config = Karafka::App.config.internal.active_job

assert_equal aj_config.consumer_class, Karafka::Pro::ActiveJob::Consumer
assert_equal aj_config.dispatcher.class, Karafka::Pro::ActiveJob::Dispatcher
assert_equal aj_config.job_options_contract.class, Karafka::Pro::ActiveJob::JobOptionsContract
assert_equal VALUE1, DT[0][0]
assert_equal VALUE2, DT[0][1]
assert_equal 1, DT.data.size
