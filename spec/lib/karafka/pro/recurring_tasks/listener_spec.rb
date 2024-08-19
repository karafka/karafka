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
end
