# topics:
#   - karafka_recurring_tasks_schedules
#   - karafka_recurring_tasks_executions

class Schedule
  attr_reader :version

  def initialize(version:)
    @version = version
    @tasks = {}
  end

  def <<(task)
    @tasks[task.id] = task
  end

  def each(&block)
    @tasks.each_value(&block)
  end

  def find(id)
    @tasks[id]
  end
end

class Task
  attr_reader :id

  def initialize(id:, cron:, previous_time: 0, enabled: true, &block)
    @id = id
    @cron = CronParser.new(cron)
    @previous_time = previous_time.zero? ? Time.now.to_i : previous_time
    @executable = block
    @enabled = enabled
    @trigger = false
  end

  def disable
    @enabled = false
  end

  def enable
    @enabled = true0
  end

  def enabled?
    @enabled
  end

  def trigger
    @trigger = true
  end

  def next_execution_time
    @cron.next_execution_time(@previous_time)
  end

  def execute?
    return true if @trigger
    return false unless enabled?

    @cron.execution_due?(@previous_time)
  end

  def execute
    @executable.call
    @trigger = false
    @previous_time = Time.now.utc.to_i
  end
end

class CronParser
  CRON_PARTS = 5

  def initialize(cron_expression)
    @cron_parts = cron_expression.split(' ')
    raise ArgumentError, 'Invalid cron expression' unless @cron_parts.size == CRON_PARTS
  end

  def matches?(epoch_time = Time.now.to_i)
    time = Time.at(epoch_time).utc
    minute_matches?(time.min) &&
      hour_matches?(time.hour) &&
      day_matches?(time.day) &&
      month_matches?(time.month) &&
      weekday_matches?(time.wday)
  end

  def execution_due?(last_execution_time, current_time = Time.now.to_i)
    next_execution_time = calculate_next_execution(last_execution_time)

    # Ensure the job is only due if current_time is strictly after the next_execution_time
    current_time > next_execution_time
  end

  def next_execution_time(last_execution_time)
    calculate_next_execution(last_execution_time)
  end

  private

  def minute_matches?(minute)
    cron_match?(minute, @cron_parts[0], 0, 59)
  end

  def hour_matches?(hour)
    cron_match?(hour, @cron_parts[1], 0, 23)
  end

  def day_matches?(day)
    cron_match?(day, @cron_parts[2], 1, 31)
  end

  def month_matches?(month)
    cron_match?(month, @cron_parts[3], 1, 12)
  end

  def weekday_matches?(weekday)
    cron_match?(weekday, @cron_parts[4], 0, 6)
  end

  def cron_match?(value, cron_part, min_value, max_value)
    return true if cron_part == '*'

    cron_part.split(',').any? do |part|
      if part.include?('/')
        step_match?(value, part, min_value, max_value)
      elsif part.include?('-')
        range_match?(value, part)
      else
        part.to_i == value
      end
    end
  end

  def step_match?(value, cron_part, min_value, max_value)
    range, step = cron_part.split('/')
    range_start, range_end = range == '*' ? [min_value, max_value] : range.split('-').map(&:to_i)
    (range_start..range_end).step(step.to_i).include?(value)
  end

  def range_match?(value, cron_part)
    range_start, range_end = cron_part.split('-').map(&:to_i)
    (range_start..range_end).include?(value)
  end

  def calculate_next_execution(last_execution_time)
    time = Time.at(last_execution_time).utc

    next_minute = next_match(time.min, @cron_parts[0], 0, 59)
    next_hour = time.hour
    next_day = time.day
    next_month = time.month
    next_wday = time.wday

    # Adjust for the next valid execution time
    if next_minute <= time.min
      next_minute = next_match(time.min + 1, @cron_parts[0], 0, 59)
      if next_minute <= time.min
        next_minute = next_match(0, @cron_parts[0], 0, 59)
        next_hour += 1
      end
    end

    # Handle hour, day, and month rollover
    if next_minute == 0 && time.min > 30
      next_hour += 1
      next_minute = 0
    end

    if next_hour == 24
      next_hour = 0
      next_day += 1
    end

    next_time = Time.utc(
      time.year,
      next_month,
      next_day,
      next_hour,
      next_minute,
      0
    ).to_i

    # Ensure that the next execution time is in the future
    if next_time <= last_execution_time
      next_time += 60 # Add one minute
    end

    next_time
  end

  def next_match(current_value, cron_part, min_value, max_value)
    return current_value if cron_part == '*'

    possible_values = cron_part.split(',').flat_map do |part|
      if part.include?('/')
        range, step = part.split('/')
        range_start, range_end = range == '*' ? [min_value, max_value] : range.split('-').map(&:to_i)
        (range_start..range_end).step(step.to_i).to_a
      elsif part.include?('-')
        range_start, range_end = part.split('-').map(&:to_i)
        (range_start..range_end).to_a
      else
        [part.to_i]
      end
    end

    next_value = possible_values.find { |value| value > current_value }
    next_value || possible_values.first
  end
end


schedule = Schedule.new(version: '1.0')
schedule << Task.new(
  id: 'cleanup',
  cron: '*/46 * * * *',
  previous_time: 0
) do
  puts 'Cleanup job'
end

schedule << Task.new(
  id: 'ping',
  cron: '* * * * *',
  previous_time: 0
) do
  puts 'Ping'
end

#RecurringTasks.define('1.0') do
#  schedule(id: 'cleanup', cron: '0 0 * * *') do
#    CleanupJob.new.perform
#  end
#
#  schedule(id: 'send_emails', cron: '*/5 * * * *') do
#    EmailJob.new.perform
#  end
#end

#recurring_tasks_topic :my_topic do
#  manual_offset_management true
#end

module Errors
  BaseError = Class.new(StandardError)

  IncompatibleSchemaError = Class.new(BaseError)
end

loop do
  schedule.each do |task|
    next unless task.execute?

    task.execute
  end

  sleep(1)
end


#class RecurringTasks::Consumer < ::Karafka::BaseConsumer
#  def consume
#    @current_state = {}
#    @pending_commands = {}
#
#    messages.each do |message|
#      case message.payload[:type]
#      when 'command'
#        @pending_commands << message.payload
#      when 'state'
#        @current_state = message.payload
#      when 'execution'
#        next
#      else
#        raise
#      end
#    end
#
#    # loaded is when we loaded all data until eof for the first time
#    # after that we can operate as usual
#    return unless @loaded
#  end
#
#  def tick
#    return unless @loaded
#
#    RecurringTasks.schema.version
#  end
#
#  def eofed
#    return if @loaded
#
#    @loaded = true
#
#    # If we have the current state on eofed, nothing to do
#    # only when there was no data in the topic we initialize the first state
#    return if @current_state
#    return if RecurringTasks.tasks.empty?
#
#    @current_state = build_initial_state
#
#    # return unless tasks
#    # @current_state to json
#    Karafka.producer.produce_async(
#      topic: topic.name,
#      partition: partition,
#      payload: {
#        schema_version: '1.0',
#        schedule_version: '1.0',
#        tasks: {
#          name: {
#            id: 'name',
#            cron: '*/5 * * * *',
#            previous_time: 0,
#            next_time: 0
#          }
#        }
#      }
#    )
#  end
#end
