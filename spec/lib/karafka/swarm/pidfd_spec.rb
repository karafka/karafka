# frozen_string_literal: true

RSpec.describe Karafka::Swarm::Pidfd, mode: :fork do
  let(:pidfd) { nil }

  after do
    pidfd&.signal('KILL')
    pidfd&.cleanup
  end

  context 'when fork is already dead' do
    subject(:pidfd) { described_class.new(fork {}) }

    # Give the fork time to die
    before do
      pidfd
      sleep(0.5)
    end

    it { expect(pidfd.alive?).to be(false) }
    it { expect(pidfd.signal('TERM')).to be(false) }
    it { expect { pidfd.cleanup }.not_to raise_error }
  end

  context 'when fork is alive and we decide to kill it' do
    subject(:pidfd) { described_class.new(fork { sleep(60) }) }

    before { pidfd }

    it { expect(pidfd.alive?).to be(true) }
    it { expect(pidfd.signal('TERM')).to be(true) }

    context 'when fork was killed by us' do
      before do
        pidfd.signal('KILL')
        sleep(0.5)
      end

      it { expect(pidfd.alive?).to be(false) }
    end
  end

  context 'when we try to clean an already cleaned fork' do
    subject(:pidfd) { described_class.new(fork {}) }

    before do
      pidfd
      sleep(0.5)
      pidfd.cleanup
    end

    it { expect { pidfd.cleanup }.not_to raise_error }
  end

  context 'when we try to send a signal to an already cleaned fork' do
    subject(:pidfd) { described_class.new(fork {}) }

    before do
      pidfd
      sleep(0.5)
      pidfd.cleanup
      # Fake being alive to simulate a race condition
      # note: since we do not signal after cleanup, this will not affect the execution
      allow(IO).to receive(:select).and_return(nil)
    end

    it { expect(pidfd.signal('TERM')).to be(false) }
  end

  context 'when we could not open a pid' do
    it { expect { described_class.new(0) }.to raise_error(Karafka::Errors::PidfdOpenFailedError) }
  end

  context 'when checking if supported' do
    # Keep in mind, this will fail on other OSes than linux
    it { expect(described_class.supported?).to be(true) }
  end
end
