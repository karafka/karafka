# frozen_string_literal: true

# When restoring CurrentAttributes from a job payload fails part way (here on an attribute the
# consumer does not declare, e.g. during a rolling deploy, after a declared one was already set),
# the values already set must be reset, so they do not leak into the next job processed on the
# same worker thread.

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 1
end

setup_active_job

require "karafka/active_job/current_attributes"

draw_routes do
  active_job_topic DT.topic do
    dead_letter_queue topic: DT.topics[1], max_retries: 0
  end

  topic DT.topics[1] do
    active(false)
  end
end

class Current < ActiveSupport::CurrentAttributes
  attribute :tenant
end

Karafka::ActiveJob::CurrentAttributes.persist(Current)

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event[:error].class
end

class RestoredJob < ActiveJob::Base
  queue_as DT.topic

  def perform
    DT[:restored_tenant] << Current.tenant
  end
end

class FollowingJob < ActiveJob::Base
  queue_as DT.topic

  def perform
    DT[:following_tenant] << Current.tenant
  end
end

payload = RestoredJob.new.serialize.merge(
  "cattr_0" => { "tenant" => "leaked-tenant", "region" => "eu" }
)

Karafka.producer.produce_sync(topic: DT.topic, payload: payload.to_json)
FollowingJob.perform_later

start_karafka_and_wait_until do
  DT.key?(:following_tenant)
end

assert_equal [nil], DT[:following_tenant], DT[:following_tenant]
assert_equal [], DT[:restored_tenant]
assert DT[:errors].include?(ArgumentError), DT[:errors]
