# frozen_string_literal: true

# When a declared CurrentAttributes writer raises after setting its value while a job is being
# restored, all the values already set must be reset, so they do not leak into the next job
# processed on the same worker thread.

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
  attribute :tenant, :account

  def account=(value)
    super
    raise StandardError, "unknown account" if value == "missing"
  end
end

Karafka::ActiveJob::CurrentAttributes.persist(Current)

class RestoredJob < ActiveJob::Base
  queue_as DT.topic

  def perform
    DT[:restored_tenant] << Current.tenant
  end
end

class FollowingJob < ActiveJob::Base
  queue_as DT.topic

  def perform
    DT[:following] << [Current.tenant, Current.account]
  end
end

payload = RestoredJob.new.serialize.merge(
  "cattr_0" => { "tenant" => "leaked-tenant", "account" => "missing" }
)

Karafka.producer.produce_sync(topic: DT.topic, payload: payload.to_json)
FollowingJob.perform_later

start_karafka_and_wait_until do
  DT.key?(:following)
end

assert_equal [[nil, nil]], DT[:following], DT[:following]
assert_equal [], DT[:restored_tenant]
