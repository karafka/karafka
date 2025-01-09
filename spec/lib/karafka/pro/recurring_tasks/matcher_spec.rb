# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:matcher) { described_class.new }

  let(:task) { Karafka::Pro::RecurringTasks::Task.new(id: 'task 1', cron: '* * * * *') }
  let(:schema_version) { '1.0' }

  let(:payload) do
    {
      type: 'command',
      task: { id: task_id },
      schema_version: schema_version
    }
  end

  before do
    schedule = Karafka::Pro::RecurringTasks::Schedule.new(version: '1.0.1')
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
        expect(matcher.matches?(task, payload)).to be(false)
      end
    end

    context 'when task id in payload does not match task id' do
      let(:task_id) { 'different_task_id' }

      it 'returns false' do
        expect(matcher.matches?(task, payload)).to be(false)
      end
    end

    context 'when task id in payload is wildcard (*)' do
      let(:task_id) { '*' }

      it 'returns true' do
        expect(matcher.matches?(task, payload)).to be(true)
      end
    end

    context 'when schema version in payload does not match' do
      let(:task_id) { task.id }
      let(:schema_version) { '0.9' }

      it 'returns false' do
        expect(matcher.matches?(task, payload)).to be(false)
      end
    end

    context 'when all conditions match' do
      let(:task_id) { task.id }

      it 'returns true' do
        expect(matcher.matches?(task, payload)).to be(true)
      end
    end
  end
end
