# frozen_string_literal: true

RSpec.describe_current do
  subject(:status_manager) { described_class.new }

  let(:initial_status) { :pending }

  describe 'initial state' do
    it { expect(status_manager.pending?).to eq true }
    it { expect(status_manager.starting?).to eq false }
    it { expect(status_manager.running?).to eq false }
    it { expect(status_manager.quieting?).to eq false }
    it { expect(status_manager.quiet?).to eq false }
    it { expect(status_manager.stopping?).to eq false }
    it { expect(status_manager.stopped?).to eq false }
    it { expect(status_manager.active?).to eq false }
  end

  Karafka::Connection::Status::STATES.each do |state, transition|
    # This is a separate case tested out below
    next if state == :stopping

    describe "##{transition}" do
      context "when transitioning to #{state}" do
        before { status_manager.public_send(transition) }

        it { expect(status_manager.public_send("#{state}?")).to eq true }
      end
    end
  end

  describe '#stop!' do
    context 'when in pending state' do
      before do
        status_manager.pending!
        status_manager.stop!
      end

      it { expect(status_manager.stopped?).to eq true }
      it { expect(status_manager.active?).to eq false }
    end

    context 'when in running state' do
      before do
        status_manager.running!
        status_manager.stop!
      end

      it { expect(status_manager.stopping?).to eq true }
      it { expect(status_manager.active?).to eq true }
    end

    context 'when already stopped' do
      before do
        status_manager.stopped!
        status_manager.stop!
      end

      it { expect(status_manager.stopped?).to eq true }
      it { expect(status_manager.active?).to eq false }
    end
  end

  describe '#active?' do
    context 'when status is pending or stopped' do
      it 'returns false' do
        status_manager.pending!
        expect(status_manager.active?).to eq false

        status_manager.stopped!
        expect(status_manager.active?).to eq false
      end
    end

    context 'when status is neither pending nor stopped' do
      it 'returns true' do
        status_manager.start!
        expect(status_manager.active?).to eq true

        status_manager.running!
        expect(status_manager.active?).to eq true
      end
    end
  end

  describe '#reset!' do
    context 'when trying to reset from active' do
      before { status_manager.running! }

      it 'expect not to change' do
        expect { status_manager.reset! }.not_to change(status_manager, :running?)
      end
    end

    context 'when trying to reset from stopped' do
      before { status_manager.stopped! }

      it 'expect to change' do
        expect { status_manager.reset! }.to change(status_manager, :pending?).from(false).to(true)
      end
    end
  end
end
