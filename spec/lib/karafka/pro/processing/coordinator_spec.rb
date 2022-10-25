# frozen_string_literal: true

RSpec.describe_current do
  subject(:coordinator) { described_class.new(pause_tracker) }

  let(:pause_tracker) { build(:time_trackers_pause) }
  let(:last_message) { build(:messages_message) }
  let(:messages) { [last_message] }

  it { expect(described_class).to be < Karafka::Processing::Coordinator }

  before { coordinator.start(messages) }

  describe '#finished?' do
    context 'when no jobs are running' do
      it { expect(coordinator.finished?).to eq(true) }
    end

    context 'when there are running jobs' do
      before { coordinator.increment }

      it { expect(coordinator.finished?).to eq(false) }
    end
  end

  describe '#on_enqueued' do
    context 'when executed for the first time' do
      it 'expect to run with first and last message info' do
        args = [last_message]
        expect { |block| coordinator.on_enqueued(&block) }.to yield_with_args(*args)
      end
    end

    context 'when executed already once' do
      before { coordinator.on_enqueued {} }

      it 'expect not to run again' do
        expect { |block| coordinator.on_enqueued(&block) }.not_to yield_control
      end
    end
  end

  describe '#on_started' do
    context 'when executed for the first time' do
      it 'expect to run with first and last message info' do
        args = [last_message]
        expect { |block| coordinator.on_started(&block) }.to yield_with_args(*args)
      end
    end

    context 'when executed already once' do
      before { coordinator.on_started {} }

      it 'expect not to run again' do
        expect { |block| coordinator.on_started(&block) }.not_to yield_control
      end
    end
  end

  describe '#on_finished' do
    context 'when executed for the first time' do
      it 'expect to run with first and last message info' do
        args = [last_message]
        expect { |block| coordinator.on_finished(&block) }.to yield_with_args(*args)
      end
    end

    context 'when executed already once' do
      before { coordinator.on_finished {} }

      it 'expect not to run again' do
        expect { |block| coordinator.on_finished(&block) }.not_to yield_control
      end
    end
  end
end
