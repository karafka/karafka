# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# F33: the scheduled-messages consumer flips loading -> loaded via a wall-clock heuristic when EOF
# does not fire (high turnover): it flips once a batch's last message CreateTime exceeds
# `started_at + GRACE_PERIOD`. A schedule produced with a CreateTime in the (near) future (producer
# clock skew or an explicitly set future timestamp), read mid-backlog, used to satisfy that gate
# while its later cancel tombstone was still unread - `loaded!` flipped and the same consume
# dispatched the schedule before the tombstone that cancels it had been loaded (double dispatch).
#
# Reproduced with a schedule that is due now but carries a future CreateTime, a constant flow of
# far-future schedules on the same partition to keep EOF from ever firing, and a cancel produced
# dynamically once the schedule is buffered. A correct consumer does not treat the future timestamp
# as catch-up, so it reads the cancel before loading and never dispatches.

setup_karafka

draw_routes do
  scheduled_messages(DT.topics[0])

  topic DT.topics[1] do
    config(partitions: 1)
    active(false)
  end
end

# The victim: due now, but produced with a CreateTime in the future (the bug trigger). Offset 0.
schedule = Karafka::Pro::ScheduledMessages.schedule(
  message: { topic: DT.topics[1], key: "0", payload: "scheduled" },
  epoch: Time.now.to_i,
  envelope: { topic: DT.topics[0], partition: 0 }
)

Karafka.producer.produce_sync(schedule.merge(timestamp: Time.now + 300))

# Constant flow of far-future schedules with future CreateTimes on the same partition: never
# buffered (beyond today) nor dispatched, but they keep the consumer from ever reaching EOF, so
# loading -> loaded can only come from the timestamp heuristic (the bug's scenario). Because every
# message carries a future CreateTime, the bug flips loaded! at once on any batch, while the fix
# clamps them and only flips once the real 15s grace period has elapsed.
flow = Thread.new do
  loop do
    Karafka.producer.produce_sync(
      Karafka::Pro::ScheduledMessages.schedule(
        message: { topic: DT.topics[1], key: SecureRandom.uuid, payload: "noise" },
        epoch: Time.now.to_i + 100_000,
        envelope: { topic: DT.topics[0], partition: 0 }
      ).merge(timestamp: Time.now + 300)
    )

    sleep(0.1)
  rescue WaterDrop::Errors::ProducerClosedError
    break
  end
end

cancelled = false

start_karafka_and_wait_until(sleep: 1) do
  dispatched = Karafka::Admin.read_topic(DT.topics[1], 0, 100) || []

  # The buggy path dispatches our schedule before the cancel is read
  if dispatched.any? { |message| message.raw_payload == "scheduled" }
    true
  else
    # Once the consumer is up (it has reported a state), cancel the schedule - well within the 15s
    # grace - then keep running past the grace period so that, if the schedule were still buffered,
    # loaded! (which the fix delays to the grace) would have dispatched it.
    if !cancelled && Karafka::Admin.read_topic("#{DT.topics[0]}_states", 0, 1).any?
      cancelled = true
      DT[:cancelled_at] = Time.now.to_f

      Karafka.producer.produce_sync(
        Karafka::Pro::ScheduledMessages.cancel(
          key: schedule[:key],
          envelope: { topic: DT.topics[0], partition: 0 }
        )
      )
    end

    cancelled && (Time.now.to_f - DT[:cancelled_at]) > 25
  end
end

flow.kill

dispatched = Karafka::Admin.read_topic(DT.topics[1], 0, 100) || []

assert(
  dispatched.none? { |message| message.raw_payload == "scheduled" },
  "scheduled message was dispatched despite its cancel tombstone (premature load on future CreateTime)"
)
