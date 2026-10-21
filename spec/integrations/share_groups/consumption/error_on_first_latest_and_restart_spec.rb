# frozen_string_literal: true

# Share group (KIP-932) with the default `share.auto.offset.reset` (`latest`) failing on the very
# first record it gets. Unlike a consumer group (that has no offset to commit and starts from
# "latest" again after a restart, skipping the record), the share partition start offset is kept
# by the broker, so the failed record is released and delivered again after a restart.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::ShareConsumer
  def consume
    run = DT.key?(:second_run) ? :second : :first

    messages.each do |message|
      DT[run] << [message.raw_payload, message.delivery_count]
    end

    return messages.each { |message| mark_as_accepted(message) } if run == :second

    # Fail only once the stop was requested, so the released records are not redelivered (and
    # failed again) before the restart
    sleep(0.1) until Karafka::App.stopping?

    raise StandardError
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

# No group level configuration, so the broker default (latest) applies
Karafka::Admin.create_topic(DT.topic, 1, 1)

Thread.new do
  # We do not know when the share partition gets initialized, so we keep producing until the
  # first record shows up
  index = 0

  while DT[:first].empty?
    produce(DT.topic, index.to_s)
    index += 1
    sleep(1)
  end
end

start_karafka_and_wait_until(reset_status: true) do
  DT[:first].any?
end

failed = DT[:first].map(&:first)

DT[:second_run] = true

start_karafka_and_wait_until do
  (failed - DT[:second].map(&:first)).empty?
end

assert_equal [1], DT[:first].map(&:last).uniq
# The records failed on the first run were not skipped despite the `latest` reset
failed.each do |payload|
  assert DT[:second].any? { |second, count| second == payload && count >= 2 }
end
