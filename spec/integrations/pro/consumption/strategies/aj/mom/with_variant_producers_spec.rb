# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to define producer variants and use them to dispatch different jobs based
# on our preferences

class Bench
  include Karafka::Core::Helpers::Time

  def bench
    start = monotonic_now
    yield
    monotonic_now - start
  end
end

setup_karafka
setup_active_job

draw_routes do
  active_job_topic DT.topics[0] do
    active false
  end

  active_job_topic DT.topics[1] do
    active false
  end
end

LOW_QUALITY_VARIANT = Karafka.producer.with(topic_config: { acks: 0 })

class JobA < ActiveJob::Base
  queue_as DT.topics[0]

  karafka_options(
    dispatch_method: :produce_sync,
    producer: lambda do |job|
      DT[:jobs] << job.class
      LOW_QUALITY_VARIANT
    end
  )

  def perform; end
end

class JobB < ActiveJob::Base
  queue_as DT.topics[0]

  karafka_options(
    dispatch_method: :produce_async,
    # Not needed, set here to be explicit. Will use Karafka.producer
    producer: nil
  )

  def perform; end
end

slow = Bench.new.bench { 1000.times { JobA.perform_later } }
fast = Bench.new.bench { 1000.times { JobB.perform_later } }

# It should take at least 1 second more (probably way more) to send via slow variant
assert slow - fast > 1_000

assert(DT[:jobs].all? { |job_class| job_class == JobA })
