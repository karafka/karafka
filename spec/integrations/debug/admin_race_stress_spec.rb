# frozen_string_literal: true

# Stress test: replicate the EXACT race condition that makes the producer monitor
# overwrite spec flaky.
#
# The spec's flow:
# 1. setup_karafka creates default producer (allow.auto.create.topics = true from dev defaults)
#    This producer's rdkafka handle has a polling thread that periodically does metadata requests.
# 2. Admin.create_topic creates the topic, with_re_wait polls metadata
# 3. Default producer is replaced with one that has auto-create disabled
# 4. Produce via replaced producer (auto-create disabled)
#
# The race: the default producer's rdkafka handle sends a Produce/Fetch request for a
# topic while Admin.create_topic is in flight (between CreateTopicsRequest and its
# visibility). The broker auto-creates the topic, then the admin's CreateTopicsRequest
# arrives → TOPIC_ALREADY_EXISTS.
#
# Run locally:
#   KARAFKA_SPEC_PATH=spec/integrations/debug/admin_race_stress_spec.rb \
#     ruby spec/integrations/debug/admin_race_stress_spec.rb
# Then inspect broker logs for "Auto topic creation failed for it-race-"
#
# Remove after hypothesis is confirmed/denied.

setup_karafka

TOPICS = 50.times.map { "it-race-#{SecureRandom.hex(6)}" }

TOPICS.each do |topic|
  # The admin creates the topic with with_re_wait metadata polling
  # The default producer (from setup_karafka) is alive but unused at this point
  Karafka::Admin.create_topic(topic, 1, 1)

  # Replace the default producer with one that has auto-create disabled
  # This is the exact same flow as the flaky spec
  Karafka::App.config.producer = WaterDrop::Producer.new do |p_config|
    p_config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
    p_config.kafka[:"allow.auto.create.topics"] = false
  end

  # Produce via the REPLACED producer (auto-create disabled)
  Karafka.producer.produce_sync(topic: topic, payload: "stress")
end

sleep(1)

TOPICS.each { |topic| Karafka::Admin.delete_topic(topic) }
