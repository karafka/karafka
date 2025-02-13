# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should match over complex regexp as long as they comply with the following format:
# https://github.com/ccxvii/minilibs/blob/master/regexp.c

setup_karafka do |config|
  config.kafka[:'topic.metadata.refresh.interval.ms'] = 2_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise if topic.name.include?('sandbox')

    DT[0] << topic
  end
end

ENDING = SecureRandom.uuid

draw_routes(create_topics: false) do
  pattern(/it-(us([0-9]){2}\.)?production\.#{ENDING}/) do
    consumer Consumer
  end
end

# If works, won't hang.
start_karafka_and_wait_until do
  unless @created
    sleep(5)
    produce_many("it-production.#{ENDING}", DT.uuids(1))
    produce_many("it-us01.production.#{ENDING}", DT.uuids(1))
    produce_many("it-sandbox.production.#{ENDING}", DT.uuids(1))
    @created = true
  end

  DT[0].uniq.size >= 2
end
