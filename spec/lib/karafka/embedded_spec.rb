# frozen_string_literal: true

RSpec.describe_current do
  subject(:embedded) { described_class }

  describe '#start' do
    # The fact that it runs in a separate thread (non-blocking) is checked in the integrations
    before { allow(Karafka::Server).to receive(:start) }

    it 'expect to invoke server start' do
      embedded.start
      sleep(0.1)
      expect(Karafka::Server).to have_received(:start)
    end
  end

  describe '#stop' do
    before { allow(Karafka::Server).to receive(:stop) }

    it 'expect to invoke server stop' do
      embedded.stop
      expect(Karafka::Server).to have_received(:stop)
    end
  end

  describe '#quiet' do
    before { allow(Karafka::Server).to receive(:quiet) }

    it 'expect to invoke server quiet' do
      embedded.quiet
      expect(Karafka::Server).to have_received(:quiet)
    end
  end
end
