# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Fast jobs should also not have any problems (though not recommended) when running as lrj

setup_karafka

setup_active_job

draw_routes do
  active_job_topic DT.topic do
    long_running_job true
  end
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    DT[0] << value
  end
end

100.times { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DT[0].size >= 100
end

100.times do |value|
  assert_equal value, DT[0][value]
end
