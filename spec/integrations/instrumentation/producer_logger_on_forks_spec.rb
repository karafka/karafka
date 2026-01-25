# frozen_string_literal: true

# After fork unused producer logger should work as expected
#
# Note: We check this because rdkafka had an issue where fork logger would not work at all.

setup_karafka do |config|
  # This will trigger extensive logs that should be visible from a fork
  config.kafka[:debug] = "all"
end

reader, writer = IO.pipe

pid = fork do
  $stdout.reopen(writer)
  reader.close
  Karafka.producer.produce_sync(topic: DT.topic, payload: "1")
  writer.close
end

writer.close

output = reader.read

Process.wait(pid)

# It should have a lot of debug info from the child fork when logger works
assert output.split("\n").size > 50
