# frozen_string_literal: true

RSpec.describe_current do
  include Karafka::Core::Helpers::Time

  subject(:manager) { described_class.new }

  let(:listener_class) { Karafka::Connection::Listener }
  let(:listener_g11) { listener_class.new(subscription_group1, jobs_queue, scheduler) }
  let(:listener_g12) { listener_class.new(subscription_group1, jobs_queue, scheduler) }
  let(:subscription_group1) { build(:routing_subscription_group, topics: [routing_topic1]) }
  let(:listener_g21) { listener_class.new(subscription_group2, jobs_queue, scheduler) }
  let(:listener_g22) { listener_class.new(subscription_group2, jobs_queue, scheduler) }
  let(:subscription_group2) { build(:routing_subscription_group, topics: [routing_topic2]) }
  let(:routing_topic1) { build(:routing_topic) }
  let(:routing_topic2) { build(:routing_topic) }
  let(:status) { Karafka::Connection::Status.new }
  let(:listeners) do
    batch = Karafka::Connection::ListenersBatch.new(nil)
    batch.instance_variable_set(:@batch, [listener_g11, listener_g12, listener_g21, listener_g22])
    batch
  end

  let(:jobs_queue) { Karafka::Processing::JobsQueue.new }
  let(:scheduler) { Karafka::Processing::Schedulers::Default.new(jobs_queue) }
  let(:app) { Karafka::App }

  before do
    Karafka::Connection::Status::STATES.each_value do |transition|
      listeners.each do |listener|
        allow(listener).to receive(transition).and_call_original
        allow(listener).to receive(:"#{transition}?").and_call_original
      end
    end

    listeners.each { |listener| allow(listener).to receive(:start!) }
  end

  describe '#register' do
    it 'expect to start all listeners if none in multiplexed mode' do
      manager.register(listeners)

      expect(listeners).to all have_received(:start!)
    end

    context 'when we operate in a non-dynamic multiplexed mode' do
      before do
        subscription_group1.multiplexing.active = true
        subscription_group1.multiplexing.min = 2
        subscription_group1.multiplexing.max = 2
        subscription_group1.multiplexing.boot = 2
      end

      it 'expect to start all listeners' do
        manager.register(listeners)

        expect(listeners).to all have_received(:start!)
      end
    end

    context 'when we operate in a dynamic multiplexed mode' do
      before do
        subscription_group1.multiplexing.active = true
        subscription_group1.multiplexing.min = 1
        subscription_group1.multiplexing.max = 2
        subscription_group1.multiplexing.boot = 1

        manager.register(listeners)
      end

      it 'expect to start all non-dynamic' do
        expect(listener_g21).to have_received(:start!)
        expect(listener_g22).to have_received(:start!)
      end

      it 'expect to start boot dynamic' do
        expect(listener_g11).to have_received(:start!)
        expect(listener_g12).not_to have_received(:start!)
      end
    end
  end

  describe '#notice' do
    let(:statistics) { JSON.parse(fixture_file('statistics.json')) }
    let(:changes) { manager.instance_variable_get(:@changes) }
    let(:details) { changes.values.first }

    before do
      manager.register(listeners)
    end

    it { expect(changes).to be_empty }

    context 'when notice was used' do
      before { manager.notice(subscription_group1.id, statistics) }

      it { expect(changes.keys).to eq([subscription_group1.id]) }
      it { expect(details[:state_age]).to eq(13_995) }
      it { expect(details[:join_state]).to eq('steady') }
      it { expect(details[:state]).to eq('up') }
      it { expect(monotonic_now - details[:changed_at]).to be < 10 }
      it { expect(monotonic_now - details[:state_age_sync]).to be < 10 }
    end
  end

  describe '#control' do
    before { allow(app).to receive(:done?).and_return(done) }

    context 'when processing is done' do
      let(:done) { true }

      it 'expect to run shutdown' do
        allow(manager).to receive(:shutdown)
        manager.control
        expect(manager).to have_received(:shutdown)
      end
    end

    context 'when processing is not done' do
      let(:done) { false }

      it 'expect to run rescale' do
        allow(manager).to receive(:rescale)
        manager.control
        expect(manager).to have_received(:rescale)
      end
    end
  end

  describe '#shutdown' do
    let(:quiet) { false }

    before do
      listener_g11.running!
      listener_g21.running!

      manager.register(listeners)
      allow(app).to receive(:done?).and_return(true)
      allow(app).to receive(:quiet?).and_return(quiet)
    end

    context 'when under quiet' do
      before do
        allow(app).to receive(:done?).and_return(true)
        allow(app).to receive(:quieting?).and_return(true)
        allow(app).to receive(:quieted!).and_return(true)
      end

      context 'when it just started' do
        it 'expect to switch listeners to quieting' do
          manager.control

          expect(listener_g11).to have_received(:quiet!)
          expect(listener_g21).to have_received(:quiet!)
          expect(listener_g12).to_not have_received(:quiet!)
          expect(listener_g22).to_not have_received(:quiet!)
        end
      end

      context 'when not all listeners are quieted' do
        it 'expect not to switch process to quiet' do
          manager.control

          expect(app).not_to have_received(:quieted!)
        end
      end

      context 'when all listeners are quieted' do
        before do
          allow(app).to receive(:quiet?).and_return(true)

          manager.control
          listeners.each(&:quieted!)
          manager.control
        end

        it 'expect to switch whole process to quieted' do
          expect(app).to have_received(:quieted!)
        end

        it 'expect not to move them forward to stopping' do
          listeners.each do |listener|
            expect(listener).not_to have_received(:stop!)
          end
        end
      end
    end
  end
end
