# frozen_string_literal: true

# When Karafka receives sigttin, it should print some backtrace details using logger when
# logger listener is enabled

# Here it is enabled by default

require 'stringio'

strio = StringIO.new

setup_karafka do |config|
  config.logger = Logger.new(strio)
end

class Consumer < Karafka::BaseConsumer
  # Do nothing
  def consume; end
end

draw_routes(Consumer)

produce(DT.topic, '1')

Thread.new do
  sleep(5)

  Process.kill('TTIN', Process.pid)

  sleep(1)

  Process.kill('INT', Process.pid)
end

start_karafka_and_wait_until { false }

assert strio.string.include?('Received SIGTTIN system signal')
assert strio.string.include?('Thread TID-')
