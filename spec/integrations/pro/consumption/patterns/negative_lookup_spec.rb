# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
  DT[0].uniq.size >= 2
end
