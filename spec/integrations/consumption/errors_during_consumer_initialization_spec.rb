# frozen_string_literal: true

# Karafka should handle errors in consumer lifecycle hooks gracefully

setup_karafka

class LifecycleErrorConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << message.raw_payload
    end
  end

  def initialized
    DT[:initialized_called] = true
    # Simulate error during initialized hook
    raise StandardError, 'Error in initialized hook'
  end
end

draw_routes(LifecycleErrorConsumer)

produce(DT.topic, 'test_message')

# The framework should handle lifecycle hook errors gracefully
start_karafka_and_wait_until do
  DT[:consumed].size >= 1 || DT[:initialized_called]
end

# Even with errors in lifecycle hooks, basic consumption should work
# The framework logs the error but continues operation
assert DT[:initialized_called], 'Should call initialized hook'

# The key test: lifecycle errors don't prevent message consumption
# Messages should still be consumed despite hook errors
assert(
  DT[:consumed].size >= 1,
  'Should consume messages despite lifecycle hook errors'
)

assert(
  DT[:consumed].include?('test_message'),
  'Should process test message despite initialization hook error'
)
