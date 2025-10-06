# frozen_string_literal: true

RSpec.describe_current do
  subject(:manager) { described_class.new }

  # Set a very short pause timeout for tests that check pause expiration
  before do
    Karafka::App.setup do |c|
      c.pause.timeout = 1
      c.pause.max_timeout = 1
    end
  end

  # Reset to defaults after all tests
  after do
    Karafka::App.setup do |c|
      c.pause.max_timeout = 30_000
      c.pause.timeout = 1_000
      c.pause.with_exponential_backoff = true
    end
  end

  let(:topic) { build(:routing_topic) }
  let(:partition) { rand(0..100) }
  let(:fetched_pause) { manager.fetch(topic, partition) }

  describe '#fetch' do
    context 'when a pause is already present' do
      let(:prefetch_pause) { manager.fetch(topic, partition) }

      before { prefetch_pause }

      it { expect(fetched_pause).to eq(prefetch_pause) }
    end

    context 'when pause for given topic partition was not present' do
      it { expect(fetched_pause).to be_a(Karafka::TimeTrackers::Pause) }
    end
  end

  describe '#resume' do
    context 'when there is no pause that is expired' do
      before { fetched_pause }

      it { expect { |block| manager.resume(&block) }.not_to yield_control }
    end

    context 'when there is a paused and expired pause' do
      before do
        fetched_pause.pause
        sleep 0.001
      end

      it 'expect to resume it' do
        manager.resume {}
        expect(fetched_pause.paused?).to be(false)
        expect(fetched_pause.expired?).to be(true)
      end

      it 'expect to yield upon it with pause ownership details' do
        expect { |block| manager.resume(&block) }.to yield_with_args(topic, partition)
      end
    end
  end
end
