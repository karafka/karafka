# frozen_string_literal: true

# Share group (KIP-932) new groups default `share.auto.offset.reset` to `latest`: records produced
# before the group starts consuming are not delivered, records produced afterwards are.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

# No group level configuration, so the broker defaults apply
Karafka::Admin.create_topic(DT.topic, 1, 1)

before = DT.uuids(10).map { |uuid| "before-#{uuid}" }
produce_many(DT.topic, before)

Thread.new do
  # We do not know when the share partition gets initialized, so we keep producing until the
  # records start flowing
  index = 0

  while DT[:consumed].empty?
    produce(DT.topic, "after-#{index}")
    DT[:after] << "after-#{index}"
    index += 1
    sleep(1)
  end

  DT[:produced] = true
end

start_karafka_and_wait_until do
  next false unless DT.key?(:produced)

  DT[:done_at] = Time.now unless DT.key?(:done_at)

  # Give it time to make sure nothing more shows up
  Time.now - DT[:done_at] > 5
end

consumed = DT[:consumed]

assert (consumed & before).empty?
assert !consumed.empty?
assert consumed.all? { |payload| payload.start_with?("after-") }
# Once the first record produced after the start shows up, all the later ones follow
first = DT[:after].index(consumed.min_by { |payload| payload.delete_prefix("after-").to_i })
assert_equal DT[:after][first..].sort, consumed.sort
