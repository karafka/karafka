# frozen_string_literal: true

# Karafka should instrument on particular active job jobs and should include details allowing
# for correlation of jobs with topic, messages, etc

setup_karafka
setup_active_job

draw_routes do
  consumer_group DT.consumer_group do
    active_job_topic DT.topic
  end
end

Karafka::App.monitor.subscribe('active_job.consume') do |event|
  DT[:consume] << event
end

Karafka::App.monitor.subscribe('active_job.consumed') do |event|
  DT[:consumed] << event
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(_number); end
end

2.times { |nr| Job.perform_later(nr) }

start_karafka_and_wait_until do
  DT[:consumed].size >= 2
end

DT[:consume].each_with_index do |event, index|
  assert_equal DT.topic, event[:job]['queue_name']
  assert_equal [index], event[:job]['arguments']
  assert event[:message].is_a?(Karafka::Messages::Message)
  assert event[:caller].is_a?(Karafka::BaseConsumer)
  assert !event.payload.key?(:time)
end

DT[:consumed].each_with_index do |event, index|
  assert_equal DT.topic, event[:job]['queue_name']
  assert_equal [index], event[:job]['arguments']
  assert event[:message].is_a?(Karafka::Messages::Message)
  assert event[:caller].is_a?(Karafka::BaseConsumer)
  assert event.payload.key?(:time)
end
