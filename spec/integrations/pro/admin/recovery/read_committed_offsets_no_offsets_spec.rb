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

# When a consumer group has never committed any offsets, Recovery should return an empty hash.

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

GROUP_ID = SecureRandom.uuid

# Commit an offset for a *different*, throwaway group so the __consumer_offsets internal topic is
# guaranteed to exist in cluster metadata. On a fresh CI broker it may not exist until a consumer
# group has committed at least once. GROUP_ID itself intentionally never commits, so the recovery
# result for it must still be empty.
produce(DT.topic, "warmup")

Karafka::Admin.seek_consumer_group(SecureRandom.uuid, { DT.topic => { 0 => 0 } })

# On a fresh CI broker the __consumer_offsets topic may take a while to appear in cluster
# metadata even after a commit. Retry the Recovery call with exponential backoff for up to ~30 s
# before giving up with the original MetadataError.
committed = nil
backoff = 1
total_waited = 0

loop do
  committed = Karafka::Admin::Recovery.read_committed_offsets(
    GROUP_ID,
    last_committed_at: Time.now - 60
  )
  break
rescue Karafka::Pro::Admin::Recovery::Errors::MetadataError
  raise if total_waited >= 30

  sleep(backoff)
  total_waited += backoff
  backoff = [backoff * 2, 10].min
end

assert_equal({}, committed)
