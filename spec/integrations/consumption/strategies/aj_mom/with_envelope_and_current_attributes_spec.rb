# frozen_string_literal: true

# Karafka should correctly handle current attributes when using a custom envelope deserializer
# This ensures that current attributes persistence works with custom serialization formats

require 'karafka/active_job/current_attributes'

# Custom deserializer that wraps jobs in an envelope with metadata
class EnvelopedWithCurrentAttributesDeserializer < Karafka::ActiveJob::Deserializer
  # Wraps the job in an envelope with additional metadata
  # Note: We call job.serialize which will include current attributes thanks to prepending
  def serialize(job)
    job_hash = job.serialize
    envelope = {
      schema_id: 456,
      schema_version: 2,
      metadata: {
        service: 'test',
        environment: 'integration'
      },
      payload: job_hash
    }
    ::ActiveSupport::JSON.encode(envelope)
  end

  # Extracts the job from the envelope
  def deserialize(message)
    envelope = ::ActiveSupport::JSON.decode(message.raw_payload)

    # Validate envelope structure
    raise 'Invalid envelope: missing schema_id' unless envelope['schema_id']
    raise 'Invalid envelope: missing payload' unless envelope['payload']

    # Extract and return the actual job data (which includes current attributes)
    envelope['payload']
  end
end

setup_karafka do |config|
  # Configure Karafka to use our custom enveloped deserializer
  config.internal.active_job.deserializer = EnvelopedWithCurrentAttributesDeserializer.new
end

setup_active_job

draw_routes do
  active_job_topic DT.topic
end

# Define current attributes classes
class TestCurrentA < ActiveSupport::CurrentAttributes
  attribute :user_id
end

class TestCurrentB < ActiveSupport::CurrentAttributes
  attribute :request_id
end

# Register them for persistence
Karafka::ActiveJob::CurrentAttributes.persist(TestCurrentA)
Karafka::ActiveJob::CurrentAttributes.persist(TestCurrentB)

class EnvelopedWithCurrentAttributesJob < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    DT[0] << {
      value: value,
      user_id: TestCurrentA.user_id,
      request_id: TestCurrentB.request_id
    }
  end
end

# Set current attributes and dispatch jobs
10.times do |i|
  TestCurrentA.user_id = "user_#{i}"
  TestCurrentB.request_id = "req_#{i}"
  EnvelopedWithCurrentAttributesJob.perform_later(i)
end

start_karafka_and_wait_until do
  DT[0].size >= 10
end

# Verify each job received the correct current attributes
DT[0].each do |result|
  value = result[:value]
  assert_equal "user_#{value}", result[:user_id], "User ID mismatch for value #{value}"
  assert_equal "req_#{value}", result[:request_id], "Request ID mismatch for value #{value}"
end
