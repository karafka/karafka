# frozen_string_literal: true

# When a job payload carries a CurrentAttributes attribute the consumer does not declare (e.g.
# during a rolling deploy), it is skipped, the job runs with the declared ones, and those are reset
# so they do not leak into the next job processed on the same worker thread.

setup_karafka do |config|
  config.concurrency = 1
end

setup_active_job

require "karafka/active_job/current_attributes"

draw_routes do
  active_job_topic DT.topic
end

class Current < ActiveSupport::CurrentAttributes
  attribute :tenant
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
    DT[:following_tenant] << Current.tenant
  end
end

payload = RestoredJob.new.serialize.merge(
  "cattr_0" => { "tenant" => "restored-tenant", "region" => "eu" }
)

Karafka.producer.produce_sync(topic: DT.topic, payload: payload.to_json)
FollowingJob.perform_later

start_karafka_and_wait_until do
  DT.key?(:following_tenant)
end

assert_equal [nil], DT[:following_tenant], DT[:following_tenant]
assert_equal ["restored-tenant"], DT[:restored_tenant]
