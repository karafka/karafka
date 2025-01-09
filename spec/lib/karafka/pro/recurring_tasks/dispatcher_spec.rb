# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  let(:producer) { Karafka.producer }
  let(:topics) { Karafka::App.config.recurring_tasks.topics }
  let(:serializer) { Karafka::Pro::RecurringTasks::Serializer.new }
  let(:schedule_payload) { 'serialized_schedule_payload' }
  let(:command_payload) { 'serialized_command_payload' }
  let(:log_payload) { 'serialized_log_payload' }
  let(:task_id) { 'task_1' }
  let(:command_name) { 'command_name' }
  let(:schedules_topic) { 'karafka_recurring_tasks_schedules' }
  let(:logs_topic) { 'karafka_recurring_tasks_logs' }
  let(:event) do
    {
      task: Karafka::Pro::RecurringTasks::Task.new(id: task_id, cron: '* * * * *')
    }
  end

  before do
    allow(Karafka::Pro::RecurringTasks::Serializer).to receive(:new).and_return(serializer)
    allow(producer).to receive(:produce_async)
    allow(serializer).to receive_messages(
      schedule: schedule_payload,
      command: command_payload,
      log: log_payload
    )
  end

  describe '.schedule' do
    it 'produces a schedule snapshot to Kafka' do
      described_class.schedule

      expect(producer).to have_received(:produce_async).with(
        topic: schedules_topic,
        key: 'state:schedule',
        partition: 0,
        payload: schedule_payload,
        headers: { 'zlib' => 'true' }
      )
    end
  end

  describe '.command' do
    it 'produces a command request to Kafka' do
      described_class.command(command_name, task_id)

      expect(producer).to have_received(:produce_async).with(
        topic: schedules_topic,
        key: "command:#{command_name}:#{task_id}",
        partition: 0,
        payload: command_payload,
        headers: { 'zlib' => 'true' }
      )
    end
  end

  describe '.log' do
    it 'produces a task execution log record to Kafka' do
      described_class.log(event)

      expect(producer).to have_received(:produce_async).with(
        topic: logs_topic,
        key: task_id,
        partition: 0,
        payload: log_payload,
        headers: { 'zlib' => 'true' }
      )
    end
  end

  describe '.produce' do
    it 'produces a message to Kafka with the correct parameters' do
      topic = 'topic'
      key = 'key'
      payload = 'payload'

      described_class.send(:produce, topic, key, payload)

      expect(producer).to have_received(:produce_async).with(
        topic: topic,
        key: key,
        partition: 0,
        payload: payload,
        headers: { 'zlib' => 'true' }
      )
    end
  end

  describe '.producer' do
    it 'returns the recurring tasks producer' do
      expect(described_class.send(:producer)).to eq(producer)
    end
  end

  describe '.topics' do
    it 'returns the recurring tasks topics' do
      expect(described_class.send(:topics)).to eq(topics)
    end
  end

  describe '.serializer' do
    it 'returns a new instance of the Serializer' do
      expect(described_class.send(:serializer)).to eq(serializer)
    end
  end
end
