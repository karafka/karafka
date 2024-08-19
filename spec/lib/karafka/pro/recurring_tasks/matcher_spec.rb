# frozen_string_literal: true

RSpec.describe_current do
  subject(:matcher) { described_class.new }

  let(:task) { Karafka::Pro::RecurringTasks::Task.new(id: 'task 1', cron: '* * * * *') }
  let(:schedule_version) { '1.0.0' }
  let(:schema_version) { '1.0' }

  let(:payload) do
    {
      type: 'command',
      task: { id: task_id },
      schema_version: schema_version,
      schedule_version: schedule_version
    }
  end

  before do
    schedule = Karafka::Pro::RecurringTasks::Schedule.new(version: schedule_version)
    schedule << task

    allow(Karafka::Pro::RecurringTasks)
      .to receive(:schedule)
      .and_return(schedule)
  end

  describe '#matches?' do
    context 'when payload type is not command' do
      let(:payload) { super().merge(type: 'log') }
      let(:task_id) { task.id }

      it 'returns false' do
        expect(matcher.matches?(task, payload)).to eq(false)
      end
    end

    context 'when task id in payload does not match task id' do
      let(:task_id) { 'different_task_id' }

      it 'returns false' do
        expect(matcher.matches?(task, payload)).to eq(false)
      end
    end

    context 'when task id in payload is wildcard (*)' do
      let(:task_id) { '*' }

      it 'returns true' do
        expect(matcher.matches?(task, payload)).to eq(true)
      end
    end

    context 'when schema version in payload does not match' do
      let(:task_id) { task.id }
      let(:schema_version) { '0.9' }

      it 'returns false' do
        expect(matcher.matches?(task, payload)).to eq(false)
      end
    end

    context 'when schedule version in payload does not match current schedule version' do
      let(:task_id) { task.id }
      let(:schedule_version) { '2.0.0' }

      before { payload[:schedule_version] = '3.0.0' }

      it 'returns false' do
        expect(matcher.matches?(task, payload)).to eq(false)
      end
    end

    context 'when all conditions match' do
      let(:task_id) { task.id }

      it 'returns true' do
        expect(matcher.matches?(task, payload)).to eq(true)
      end
    end
  end
end
