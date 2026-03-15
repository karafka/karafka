# frozen_string_literal: true

# A producer that was closed before forking should remain closed in the child process.
# Attempting to use it should raise WaterDrop::Errors::ProducerClosedError.
# This behavior is by design - closed producers do not "resurrect" after fork.
# Users who need a working producer in a forked child must reinitialize it explicitly,
# for example using Karafka::Swarm::ProducerReplacer.

setup_karafka

READER, WRITER = IO.pipe

# Ensure the producer has been used at least once, then close it before forking
Karafka.producer.produce_sync(topic: DT.topic, payload: 'pre-fork')
Karafka.producer.close

pid = fork do
  error = begin
    Karafka.producer.produce_sync(topic: DT.topic, payload: 'post-fork')
    nil
  rescue WaterDrop::Errors::ProducerClosedError => e
    e
  end

  if error
    WRITER.puts('ProducerClosedError')
  else
    WRITER.puts('no_error')
  end

  exit!(0)
end

Process.wait(pid)

result = READER.gets&.strip

assert_equal 'ProducerClosedError', result
