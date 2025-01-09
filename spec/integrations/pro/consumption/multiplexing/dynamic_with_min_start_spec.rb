# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we start from one connection but there is space to grow, we should

setup_karafka do |config|
  c_klass = config.internal.connection.conductor.class
  m_klass = config.internal.connection.manager.class

  config.internal.connection.conductor = c_klass.new(1_000)
  config.internal.connection.manager = m_klass.new(1_000)
  config.concurrency = 1
end

class Consumer < Karafka::BaseConsumer
  def consume; end
end

draw_routes do
  subscription_group :sg do
    multiplexing(max: 5, min: 1, boot: 1)

    topic DT.topic do
      config(partitions: 10)
      consumer Consumer
    end
  end
end

# No specs needed, will hang if not scaling correctly
start_karafka_and_wait_until do
  Karafka::Server.listeners.count(&:active?) == 5
end
