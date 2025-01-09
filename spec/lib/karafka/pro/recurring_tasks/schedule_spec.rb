# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:schedule) { described_class.new(version: version) }

  let(:version) { '1.0.0' }
  let(:task) { instance_double(Karafka::Pro::RecurringTasks::Task, id: 'task_1') }

  describe '#initialize' do
    it 'initializes with a given version' do
      expect(schedule.version).to eq(version)
    end

    it 'initializes with an empty tasks hash' do
      expect(schedule.instance_variable_get(:@tasks)).to be_empty
    end
  end

  describe '#<<' do
    it 'adds a task to the schedule' do
      schedule << task
      expect(schedule.find(task.id)).to eq(task)
    end

    it 'overwrites a task with the same id' do
      another_task = instance_double(Karafka::Pro::RecurringTasks::Task, id: 'task_1')
      schedule << task
      schedule << another_task
      expect(schedule.find(task.id)).to eq(another_task)
    end
  end

  describe '#each' do
    it 'iterates over all tasks' do
      task2 = instance_double(Karafka::Pro::RecurringTasks::Task, id: 'task_2')
      schedule << task
      schedule << task2

      expect { |b| schedule.each(&b) }.to yield_successive_args(task, task2)
    end
  end

  describe '#find' do
    context 'when task exists' do
      it 'returns the task with the given id' do
        schedule << task
        expect(schedule.find(task.id)).to eq(task)
      end
    end

    context 'when task does not exist' do
      it 'returns nil' do
        expect(schedule.find('non_existent_task')).to be_nil
      end
    end
  end

  describe '#schedule' do
    let(:task_id) { 'task_1' }
    let(:cron_expression) { '* * * * *' } # Every minute

    it 'creates and adds a task to the schedule' do
      expect { schedule.schedule(id: task_id, cron: cron_expression) }
        .to change { schedule.find(task_id) }
        .from(nil)
        .to be_a(Karafka::Pro::RecurringTasks::Task)
    end

    it 'adds a task with the correct attributes' do
      schedule.schedule(id: task_id, cron: cron_expression)
      task = schedule.find(task_id)

      expect(task.id).to eq(task_id)
      expect(task.send(:instance_variable_get, :@cron).original).to eq(cron_expression)
    end

    it 'overwrites a task with the same id if scheduled again' do
      schedule.schedule(id: task_id, cron: cron_expression)
      new_cron_expression = '0 * * * *' # Every hour

      expect { schedule.schedule(id: task_id, cron: new_cron_expression) }
        .to change { schedule.find(task_id).send(:instance_variable_get, :@cron).original }
        .from(cron_expression)
        .to(new_cron_expression)
    end
  end
end
