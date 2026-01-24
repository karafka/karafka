# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# We should be able to use posix negative lookup regexps to match all except certain topics

setup_karafka

DT[0] = Set.new

class Consumer < Karafka::BaseConsumer
  def consume
    raise "#{topic.name} matched" if topic.name.include?('activities')

    DT[0] << topic
  end
end

ENDING = SecureRandom.uuid
NEGATIVE_MATCHING = <<~PATTERN.gsub(/\s+/, '')
  ^(
    [^i]|
    i[^t]|
    it[^-]|
    it-[^a]|
    it-a[^c]|
    it-ac[^t]|
    it-act[^i]|
    it-acti[^v]|
    it-activ[^i]|
    it-activi[^t]|
    it-activit[^i]|
    it-activiti[^e]|
    it-activitie[^s]|
    it-activities[^.]
  )
PATTERN

NEGATIVE_PATTERN = Regexp.new(NEGATIVE_MATCHING + ".*#{Regexp.escape(ENDING)}$")

draw_routes(create_topics: false) do
  pattern(NEGATIVE_PATTERN) do
    consumer Consumer
  end
end

produce_many("it-test.#{ENDING}", DT.uuids(1))
produce_many("it-activities.#{ENDING}", DT.uuids(1))
produce_many("it-active.#{ENDING}", DT.uuids(1))

start_karafka_and_wait_until do
  DT[0].size >= 2
end
