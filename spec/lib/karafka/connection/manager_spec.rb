# frozen_string_literal: true

RSpec.describe_current do
  subject(:manager) { described_class.new }

  let(:listener_class) { Karafka::Connection::Listener }
  let(:listener_g11) { listener_class.new(subscription_group1, jobs_queue, scheduler) }
  let(:listener_g12) { listener_class.new(subscription_group1, jobs_queue, scheduler) }
  let(:subscription_group1) { build(:routing_subscription_group, topics: [routing_topic]) }
  let(:listener_g21) { listener_class.new(subscription_group2, jobs_queue, scheduler) }
  let(:listener_g22) { listener_class.new(subscription_group2, jobs_queue, scheduler) }
  let(:subscription_group2) { build(:routing_subscription_group, topics: [routing_topic]) }
  let(:listeners) { [listener_g11, listener_g12, listener_g21, listener_g22] }
  let(:routing_topic) { build(:routing_topic) }
  let(:status) { Karafka::Connection::Status.new }

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
    it 'expect to start all listeners' do
      manager.register(listeners)

      expect(listeners).to all have_received(:start!)
    end
  end

  describe '#done?' do
    before { manager.register(listeners) }

    context 'when all listeners are done' do
      before { listeners.each(&:stopped!) }

      it { expect(manager.done?).to be(true) }
    end

    context 'when some listeners are not done' do
      it { expect(manager.done?).to be(false) }
    end
  end

  describe '#control' do
    before { manager.register(listeners) }

    context 'when under quiet' do
      before do
        allow(app).to receive_messages(
          done?: true,
          quieting?: true,
          quieted!: true
        )
      end

      context 'when it just started' do
        it 'expect to switch listeners to quieting' do
          manager.control

          expect(listeners.all?(&:quieting?)).to be(true)
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

        it 'expect to switch whole process to quieting' do
          expect(app).to have_received(:quieted!)
        end

        it 'expect not to move them forward to stopping' do
          listeners.each do |listener|
            expect(listener).not_to have_received(:stop!)
          end
        end
      end
    end

    context 'when under shutdown' do
      before { allow(app).to receive(:done?).and_return(true) }

      context 'when shutdown is happening' do
        context 'when it just started' do
          it 'expect to switch listeners to quieting' do
            manager.control

            expect(listeners.all?(&:quieting?)).to be(true)
          end
        end

        context 'when we run control multiple times during quieting' do
          before { 10.times { manager.control } }

          it 'expect not to change state from quieting' do
            expect(listeners.all?(&:quieting?)).to be(true)
          end
        end

        context 'when all listeners are quiet' do
          before do
            manager.control
            listeners.each { |listener| allow(listener).to receive(:quiet?).and_return(true) }
          end

          it 'expect to request all of them to stop' do
            manager.control
            expect(listeners.all?(&:stopping?)).to be(true)
          end
        end
      end
    end

    context 'when not under shutdown' do
      it 'expect to do nothing' do
        manager.control

        expect { listeners }.not_to(change { listeners.all?(&:quieting?) })
      end
    end
  end
end
