# frozen_string_literal: true

# Share group (KIP-932) consumer raising a process-critical error (SystemExit via `exit`) without
# a DLQ: Karafka records the failure, releases the records it did not accept and initiates a
# graceful shutdown instead of retrying in-process. Records accepted before the exit are not
# delivered again after a restart, while the failed record is redelivered and processed.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 1
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      exit(1) if message.raw_payload == "critical" && !DT.key?(:second_run)

      DT[:consumed] << [message.raw_payload, message.delivery_count]
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

setup_share_group

produce_many(DT.topic, %w[a b critical])

# First run: the critical error initiates a graceful self-stop. The wait block only observes
start_karafka_and_wait_until(reset_status: true) do
  Karafka::App.done?
end

assert !DT[:consumed].map(&:first).include?("critical")

first_run = DT[:consumed].map(&:first)

DT[:second_run] = true

# Run a bit longer than needed, so a redelivery of the accepted records would show up
start_karafka_and_wait_until do
  DT[:consumed].map(&:first).include?("critical") && sleep(3)
end

consumed = DT[:consumed].map(&:first)

assert_equal %w[a b critical], consumed.uniq.sort
# Records accepted before the critical error are not processed again after the restart
first_run.each { |payload| assert_equal 1, consumed.count(payload) }
# The failed record was released, so it comes back as a further delivery
assert DT[:consumed].find { |payload, _| payload == "critical" }.last >= 2
