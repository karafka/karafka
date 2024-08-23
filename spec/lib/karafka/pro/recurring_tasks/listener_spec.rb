# frozen_string_literal: true

RSpec.describe_current do
  subject(:listener) { described_class.new }

  let(:event) { instance_double('Karafka::Core::Monitoring::Event') }
  let(:dispatcher) { Karafka::Pro::RecurringTasks::Dispatcher }

  describe '#on_recurring_tasks_task_executed' do
    before { allow(dispatcher).to receive(:log) }

    it 'logs the event using Dispatcher' do
      listener.on_recurring_tasks_task_executed(event)

      expect(dispatcher).to have_received(:log).with(event)
    end
  end

  describe '#on_error_occurred' do
    before { allow(dispatcher).to receive(:log) }

    context 'when event type is recurring_tasks.task.execute.error' do
      let(:event) { { type: 'recurring_tasks.task.execute.error', other_data: 'data' } }

      it 'logs the event using Dispatcher' do
        listener.on_error_occurred(event)

        expect(dispatcher).to have_received(:log).with(event)
      end
    end

    context 'when event type is not recurring_tasks.task.execute.error' do
      let(:event) { { type: 'some_other_error', other_data: 'data' } }

      it 'does not log the event' do
        listener.on_error_occurred(event)

        expect(dispatcher).not_to have_received(:log)
      end
    end
  end
end
