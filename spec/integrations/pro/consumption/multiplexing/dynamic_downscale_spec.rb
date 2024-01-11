# frozen_string_literal: true

# When we start from too many connections, we should effectively go down and establish baseline

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
    multiplexing(max: 5, min: 1, boot: 5)

    topic DT.topic do
      config(partitions: 2)
      consumer Consumer
    end
  end
end

done = false

# No specs needed, will hang if not scaling correctly
start_karafka_and_wait_until do
  if Karafka::Server.listeners.count(&:active?) == 2
    sleep(10)

    done = true
  end

  done
end
