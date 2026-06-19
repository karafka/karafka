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

# F31: `Pro::Connection::Manager#stable?` memoized the multiplexing `scale_delay` with `@scale_delay
# ||= ...` on the single process-wide manager. Whichever subscription-group family was evaluated
# first permanently fixed the stability window for ALL families, so every other family ignored its
# own configured `scale_delay`.
#
# Reproduced with two multiplexed families sharing one process. Family :a is registered FIRST with a
# huge scale_delay (so on its own it never scales within the run); family :b has a small scale_delay
# and - with two partitions and five booted connections - should scale its idle connections down
# quickly. Under the bug, :a's huge delay globalizes and gates :b too, so :b stays at its boot size
# of 5 and the run hangs. With the fix, :b uses its own small delay and scales down to 2 (one
# connection per assigned partition) while :a stays at 5.

setup_karafka do |config|
  c_klass = config.internal.connection.conductor.class

  config.internal.connection.conductor = c_klass.new(1_000)
  config.concurrency = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
  end
end

draw_routes do
  # Registered first: its huge scale_delay must NOT leak into family :b
  subscription_group :a do
    multiplexing(max: 5, min: 1, boot: 5, scale_delay: 300_000)

    topic DT.topics[0] do
      config(partitions: 2)
      consumer Consumer
    end
  end

  subscription_group :b do
    multiplexing(max: 5, min: 1, boot: 5, scale_delay: 1_000)

    topic DT.topics[1] do
      config(partitions: 2)
      consumer Consumer
    end
  end
end

active_by_family = nil

# Family :b must scale its 3 idle connections down to 2 on its OWN small scale_delay, while :a
# (huge delay) stays at 5. Under the bug :b is gated by :a's delay and never scales: total active
# stays at 10 and this hangs until the run times out. We capture the per-family breakdown while the
# server is still running (after stopping, all listeners are inactive).
start_karafka_and_wait_until do
  if Karafka::Server.listeners.count(&:active?) == 7
    # Let it settle and confirm the split is steady before snapshotting
    sleep(10)

    active_by_family = Karafka::Server
      .listeners
      .select(&:active?)
      .group_by { |listener| listener.subscription_group.name }
      .transform_values(&:count)

    true
  else
    false
  end
end

# One family stayed at its boot size of 5 (:a, huge delay), the other scaled down to 2 (:b, its own
# small delay) - confirming the window is applied per family, not globally.
assert_equal([2, 5], active_by_family.values.sort)
