# frozen_string_literal: true

RSpec.describe_current do
  subject(:task) do
    described_class.new(
      id: id,
      cron: cron,
      previous_time: previous_time,
      enabled: enabled,
      &executable
    )
  end

  let(:id) { 'task_1' }
  let(:cron) { '* * * * *' }
  let(:previous_time) { Time.now - 3_600 }
  let(:enabled) { true }
  let(:executable) { -> { 'calld' } }

  describe '#initialize' do
    it 'initializes with given parameters' do
      expect(task.id).to eq(id)
      expect(task.enabled?).to eq(enabled)
    end

    it 'parses the cron expression correctly' do
      expect(task.send(:instance_variable_get, :@cron)).to be_a(Fugit::Cron)
    end
  end

  describe '#disable' do
    before { task.disable }

    it 'disables the task' do
      expect(task.enabled?).to eq(false)
    end
  end

  describe '#enable' do
    before do
      task.disable
      task.enable
    end

    it 'enables the task' do
      expect(task.enabled?).to eq(true)
    end
  end

  describe '#trigger' do
    it 'triggers the task execution' do
      task.trigger
      expect(task.send(:instance_variable_get, :@trigger)).to eq(true)
    end
  end

  describe '#next_time' do
    let(:previous_time) { Time.now }

    it 'calculates the next execution time correctly' do
      expect(task.next_time > Time.now).to eq(true)
    end
  end

  describe '#call?' do
    context 'when the task is triggered' do
      before { task.trigger }

      it 'returns true' do
        expect(task.call?).to eq(true)
      end
    end

    context 'when the task is not enabled' do
      let(:enabled) { false }

      it 'returns false' do
        expect(task.call?).to eq(false)
      end
    end

    context 'when the task is enabled and due' do
      it 'returns true' do
        allow(Time).to receive(:now).and_return(task.next_time + 1)
        expect(task.call?).to eq(true)
      end
    end

    context 'when the task is enabled but not due' do
      it 'returns false' do
        allow(Time).to receive(:now).and_return(task.next_time - 1)
        expect(task.call?).to eq(false)
      end
    end
  end

  describe '#changed?' do
    context 'when the task has not been modified' do
      it 'returns false' do
        expect(task.changed?).to eq(false)
      end
    end

    context 'when the task has been modified' do
      before { task.disable }

      it 'returns true' do
        expect(task.changed?).to eq(true)
      end
    end
  end

  describe '#clear' do
    before do
      task.disable
      task.clear
    end

    it 'clears the changed flag' do
      expect(task.changed?).to eq(false)
    end
  end

  describe '#call' do
    before { allow(Karafka.monitor).to receive(:instrument) }

    context 'when the task is executable' do
      it 'calls the block and updates previous_time' do
        task.call

        expect(task.send(:instance_variable_get, :@previous_time))
          .to be_within(1.second).of(Time.now)
      end

      it 'instruments the execution' do
        task.call

        expect(Karafka.monitor).to have_received(:instrument)
      end
    end

    context 'when an error occurs during execution' do
      let(:executable) { -> { raise StandardError, 'Execution error' } }

      it 'instruments the error occurrence' do
        task.call

        expect(Karafka.monitor).to have_received(:instrument)
      end
    end

    it 'resets the trigger after execution' do
      task.trigger
      task.call
      expect(task.send(:instance_variable_get, :@trigger)).to eq(false)
    end
  end

  describe '#touch' do
    it 'marks the task as changed' do
      task.send(:touch)
      expect(task.changed?).to eq(true)
    end
  end
end
