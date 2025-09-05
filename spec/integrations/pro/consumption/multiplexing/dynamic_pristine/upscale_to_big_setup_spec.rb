# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# This is a special spec that ensures librdkafka stability
# It is related to multiplexing that's why it is here.
#
# This spec covers this case:
#   https://github.com/confluentinc/librdkafka/issues/4783
#
# This spec runs 1.5 minute but it is expected to ensure stability of the multiplexing execution
# If the issue persists, this process will fail.
#
# This spec needs to run alone because otherwise the `top` command result can be biased by other
# specs running on the same machine alongside

Bundler.require(:default)

CONFIG = {
  'bootstrap.servers': '127.0.0.1:9092',
  'partition.assignment.strategy': 'cooperative-sticky',
  'group.id': SecureRandom.uuid
}.freeze

setup_karafka

draw_routes do
  topic DT.topics[0] do
    config(partitions: 10)
    active(false)
  end

  topic DT.topics[1] do
    config(partitions: 30)
    active(false)
  end
end

10.times do
  Thread.new do
    consumer = ::Rdkafka::Config.new(CONFIG).consumer
    DT[:consumers] << consumer
    consumer.subscribe(DT.topics[0])

    loop do
      consumer.poll(100)

      break if @stop
    end
  end
end

Thread.new do
  15.times do
    Thread.new do
      consumer = ::Rdkafka::Config.new(CONFIG).consumer
      DT[:consumers] << consumer
      consumer.subscribe(DT.topics[1])

      loop do
        consumer.poll(100)

        break if @stop
      end
    end

    break if @stop

    sleep(5)
  end
end

def cpu_usage_high?
  # Get the current process ID
  pid = Process.pid

  # Run the `top` command and get the output for the current process
  top_output = `top -b -n 1 -p #{pid}`

  # Parse the output to find the CPU usage line
  cpu_usage = nil
  top_output.each_line do |line|
    next unless line.include?(pid.to_s)

    # The CPU usage is the 9th column in the `top` command output
    cpu_usage = line.split[8].to_f
    break
  end

  # Check if the CPU usage is equal to or exceeds the threshold
  cpu_usage && cpu_usage >= 100
end

high_usage = 0

90.times do
  high_usage += 1 if cpu_usage_high?

  # We exit that way because only that way it will fully crash and not hang the process for too
  # long
  if high_usage >= 6
    puts 'Exiting due to prolonged high usage'
    exit!(1)
  end

  sleep(1)
end

@stop = true

sleep(5)

# With non-hanging consumers this will work
DT[:consumers].each(&:close)
