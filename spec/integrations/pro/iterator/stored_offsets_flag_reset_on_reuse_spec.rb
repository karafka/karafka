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

# F35: `Pro::Iterator#mark_as_consumed` latches `@stored_offsets = true` and the flag is never
# reset. The `ensure` block resets `@stopped_partitions`/`@stopped` but not `@stored_offsets`, and
# it is not (re)initialized on entry either. The end-of-loop guard
# `@current_consumer.commit_offsets(async: false) if @stored_offsets` therefore fires on EVERY
# subsequent `#each`, even though each `#each` builds a brand-new consumer (via
# `Admin.with_consumer`) that has no stored offsets - a spurious blocking sync commit on teardown.
#
# This reproduces the leak by reusing the SAME iterator: the first run marks a message (legitimately
# latching the flag and committing on teardown), the second run marks NOTHING. A correctly behaving
# iterator must not issue any sync commit on the second run's teardown because nothing was stored in
# that run. We assert on the sync commits observed on the fresh per-run consumer, so the spurious
# commit is directly visible.

setup_karafka

# We spy on the Proxy the iterator actually holds as `@current_consumer` so we can see the exact
# teardown `commit_offsets(async: false)` calls. Only sync commits (async: false) are recorded,
# since those are the teardown/`mark_as_consumed!` commits the guard is responsible for.
SYNC_COMMITS = []

sync_commit_spy = Module.new do
  def commit_offsets(tpl = nil, async: true)
    SYNC_COMMITS << caller unless async
    super
  end
end

Karafka::Connection::Proxy.prepend(sync_commit_spy)

draw_routes do
  topic DT.topic do
    active false
  end
end

produce_many(DT.topic, DT.uuids(10))

topics = { DT.topic => { 0 => true } }

settings = {
  "group.id": SecureRandom.uuid,
  "auto.offset.reset": "beginning"
}

# One iterator, reused across two independent scans - the exact reuse pattern the docs support.
iterator = Karafka::Pro::Iterator.new(topics, settings: settings)

# First run: mark one message and stop. This legitimately latches `@stored_offsets = true` and
# triggers exactly one sync commit on teardown.
iterator.each do |message|
  iterator.mark_as_consumed(message)
  iterator.stop
end

first_run_sync_commits = SYNC_COMMITS.size

# The first (legitimate) run must have committed on teardown because we marked a message.
assert_equal 1, first_run_sync_commits

# Second run on the SAME iterator: we mark NOTHING. A correct iterator stores no offsets during this
# run and thus must not perform any sync commit on teardown. With the F35 bug, `@stored_offsets` is
# still `true` from the first run, so the guard fires a spurious blocking sync commit on the fresh,
# empty-of-stored-offsets consumer.
iterator.each do |_message|
  iterator.stop
end

second_run_sync_commits = SYNC_COMMITS.size - first_run_sync_commits

# No offsets were stored in the second run, so no sync commit should have happened. Before the fix
# this is 1 (the spurious commit) and the assertion fails, pinning the bug.
assert_equal 0, second_run_sync_commits
