# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should be able to dispatch jobs via scheduled messages

setup_karafka
setup_active_job

draw_routes do
  active_job_topic DT.topics[0]
  scheduled_messages(DT.topics[1])
end

class Job < ActiveJob::Base
  queue_as DT.topic

  karafka_options(
    dispatch_method: :produce_sync,
    scheduled_messages_topic: DT.topics[1]
  )

  def perform(value1, value2)
    DT[0] << value1
    DT[0] << value2
  end
end

VALUE1 = rand
VALUE2 = rand

Job.set(wait: 5.seconds).perform_later(VALUE1, VALUE2)

start_karafka_and_wait_until do
  DT.key?(0)
end

aj_config = Karafka::App.config.internal.active_job

assert_equal aj_config.dispatcher.class, Karafka::Pro::ActiveJob::Dispatcher
assert_equal aj_config.job_options_contract.class, Karafka::Pro::ActiveJob::JobOptionsContract
assert_equal VALUE1, DT[0][0]
assert_equal VALUE2, DT[0][1]
assert_equal 1, DT.data.size
