# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
    [^a]|
    a[^c]|
    ac[^t]|
    act[^i]|
    acti[^v]|
    activ[^i]|
    activi[^t]|
    activit[^i]|
    activiti[^e]|
    activitie[^s]|
    activities[^.]
  )
PATTERN

NEGATIVE_PATTERN = Regexp.new(NEGATIVE_MATCHING + ".*#{Regexp.escape(ENDING)}$")

draw_routes(create_topics: false) do
  pattern(NEGATIVE_PATTERN) do
    consumer Consumer
  end
end

produce_many("test.#{ENDING}", DT.uuids(1))
produce_many("activities.#{ENDING}", DT.uuids(1))
produce_many("active.#{ENDING}", DT.uuids(1))

start_karafka_and_wait_until do
  DT[0].uniq.size >= 2
end
