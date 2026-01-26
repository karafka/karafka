# frozen_string_literal: true

# Karafka should be able to process ActiveJob jobs wrapped in a custom envelope
# This demonstrates a common pattern where all Kafka messages must follow a specific format
# with additional metadata wrapping the actual job payload

# Custom deserializer that wraps jobs in an envelope with metadata
# This extends the default Karafka ActiveJob deserializer
class EnvelopedJobDeserializer < Karafka::ActiveJob::Deserializer
  # Wraps the job in an envelope with additional metadata
  def serialize(job)
    job_hash = job.serialize
    envelope = {
      schema_id: 123,
      schema_version: 1,
      data: job_hash
    }
    ::ActiveSupport::JSON.encode(envelope)
  end

  # Extracts the job from the envelope
  def deserialize(message)
    envelope = ::ActiveSupport::JSON.decode(message.raw_payload)

    # Validate envelope structure
    raise "Invalid envelope: missing schema_id" unless envelope["schema_id"]
    raise "Invalid envelope: missing data" unless envelope["data"]

    # Extract and return the actual job data
    envelope["data"]
  end
end

setup_karafka do |config|
  # Configure Karafka to use our custom enveloped deserializer
  config.internal.active_job.deserializer = EnvelopedJobDeserializer.new
end

setup_active_job

draw_routes do
  active_job_topic DT.topic
end

class EnvelopedJob < ActiveJob::Base
  queue_as DT.topic

  karafka_options(
    dispatch_method: :produce_async
  )

  def perform(value1, value2, metadata_check)
    DT[0] << value1
    DT[0] << value2
    # Verify we can access job metadata
    DT[:job_id] << job_id
    DT[:queue_name] << queue_name
    DT[:metadata_check] << metadata_check
  end
end

VALUE1 = rand
VALUE2 = rand
METADATA_VALUE = "envelope_test"

# Dispatch the job - it will be wrapped in a custom envelope
EnvelopedJob.perform_later(VALUE1, VALUE2, METADATA_VALUE)

start_karafka_and_wait_until do
  DT.key?(0) && DT.key?(:metadata_check)
end

# Verify the job was executed correctly
assert_equal VALUE1, DT[0][0]
assert_equal VALUE2, DT[0][1]
assert_equal METADATA_VALUE, DT[:metadata_check].first

# Verify job metadata was preserved through the envelope
assert DT[:job_id].first.is_a?(String)
assert_equal DT.topic, DT[:queue_name].first
