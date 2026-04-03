# frozen_string_literal: true

# A producer that was closed before forking should remain closed in the child process.
# Attempting to use it should raise WaterDrop::Errors::ProducerClosedError.
# This behavior is by design - closed producers do not "resurrect" after fork.
# Users who need a working producer in a forked child must reinitialize it explicitly,
# for example using Karafka::Swarm::ProducerReplacer.

setup_karafka

Karafka::Admin.create_topic(DT.topic, 1, 1)

reader, writer = IO.pipe

# Ensure the producer has been used at least once, then close it before forking
Karafka.producer.produce_sync(topic: DT.topic, payload: "pre-fork")
Karafka.producer.close

pid = fork do
  reader.close

  error = begin
    Karafka.producer.produce_sync(topic: DT.topic, payload: "post-fork")
    nil
  rescue WaterDrop::Errors::ProducerClosedError => e
    e
  end

  if error
    writer.puts("ProducerClosedError")
  else
    writer.puts("no_error")
  end

  writer.close
  exit!(0)
end

writer.close
result = reader.gets&.strip
reader.close

Process.wait(pid)

assert_equal "ProducerClosedError", result
