# frozen_string_literal: true

RSpec.describe_current do
  subject(:coordinator) { described_class.new(pause_tracker) }

  let(:pause_tracker) { build(:time_trackers_pause) }
  let(:last_message) { build(:messages_message) }
  let(:messages) { [last_message] }
  let(:consumer) { instance_double(Karafka::BaseConsumer, messages: messages) }

  it { expect(described_class).to be < Karafka::Processing::Coordinator }
  it { expect(coordinator.collapsed?).to eq(false) }

  before { coordinator.start(messages) }

  describe '#start' do
    context 'when we start in a non-collapsed state' do
      before { coordinator.start(messages) }

      it { expect(coordinator.collapsed?).to eq(false) }
    end

    context 'when we start in a collapsed state that lapses' do
      before do
        coordinator.failure!(consumer, StandardError.new)
        coordinator.start(messages)
      end

      it { expect(coordinator.collapsed?).to eq(true) }
    end

    context 'when we start in a collapsed state that does not lapse' do
      before do
        coordinator.failure!(consumer, StandardError.new)
        coordinator.start([build(:messages_message)])
      end

      it { expect(coordinator.collapsed?).to eq(false) }
    end
  end

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

  describe '#failure!' do
    context 'when there is a failure' do
      before { coordinator.failure!(consumer, StandardError.new) }

      it 'expect not to collapse immediately after it' do
        expect(coordinator.collapsed?).to eq(false)
      end

      context 'when we start again after it' do
        before { coordinator.start(messages) }

        it { expect(coordinator.collapsed?).to eq(true) }
      end
    end
  end
end
