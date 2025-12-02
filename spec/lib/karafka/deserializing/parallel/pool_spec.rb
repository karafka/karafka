# frozen_string_literal: true

RSpec.describe_current do
  subject(:pool) { described_class.instance }

  let(:ractors_available) { RUBY_VERSION >= '4.0' && defined?(Ractor) }

  before do
    # Reset pool state before each test
    pool.instance_variable_set(:@workers, [])
    pool.instance_variable_set(:@size, 0)
    pool.instance_variable_set(:@started, false)
    pool.instance_variable_set(:@ready_port, nil)
    pool.instance_variable_set(:@dispatch_mutex, nil)
    pool.instance_variable_set(:@ready_queue, [])
  end

  describe '#initialize' do
    it 'starts with empty workers' do
      expect(pool.instance_variable_get(:@workers)).to eq([])
    end

    it 'starts with size 0' do
      expect(pool.size).to eq(0)
    end

    it 'starts not started' do
      expect(pool.started?).to be(false)
    end

    it 'starts with nil ready_port' do
      expect(pool.instance_variable_get(:@ready_port)).to be_nil
    end

    it 'starts with empty ready_queue' do
      expect(pool.instance_variable_get(:@ready_queue)).to eq([])
    end
  end

  describe '#started?' do
    context 'when pool is not started' do
      it 'returns false' do
        expect(pool.started?).to be(false)
      end
    end

    context 'when pool is started', skip: 'Requires Ruby 4.0+ with stable Ractors' do
      before { pool.start(2) }

      it 'returns true' do
        expect(pool.started?).to be(true)
      end

      it 'creates ready_port' do
        expect(pool.instance_variable_get(:@ready_port)).to be_a(Ractor::Port)
      end

      it 'creates dispatch_mutex' do
        expect(pool.instance_variable_get(:@dispatch_mutex)).to be_a(Mutex)
      end

      it 'populates ready_queue with all workers' do
        expect(pool.instance_variable_get(:@ready_queue).size).to eq(2)
      end
    end
  end

  describe '#size' do
    it 'returns 0 when not started' do
      expect(pool.size).to eq(0)
    end
  end

  describe '#dispatch_async' do
    let(:deserializer) { Class.new { def call(message); end }.new }
    let(:messages) do
      Array.new(10) do |i|
        instance_double(
          Karafka::Messages::Message,
          raw_payload: "payload_#{i}" * 100
        )
      end
    end
    let(:parallel_config) do
      OpenStruct.new(
        batch_threshold: 5,
        total_payload_threshold: 100,
        batch_size: 5
      )
    end
    let(:deserializing_config) do
      OpenStruct.new(parallel: parallel_config)
    end

    before do
      Karafka::App.config.deserializing = deserializing_config
    end

    context 'when messages array is empty' do
      it 'returns Immediate' do
        result = pool.dispatch_async([], deserializer)
        expect(result).to be_a(Karafka::Deserializing::Parallel::Immediate)
      end
    end

    context 'when pool is not started' do
      it 'returns Immediate' do
        result = pool.dispatch_async(messages, deserializer)
        expect(result).to be_a(Karafka::Deserializing::Parallel::Immediate)
      end
    end

    context 'when batch threshold is not met' do
      let(:small_messages) do
        Array.new(3) do |i|
          instance_double(
            Karafka::Messages::Message,
            raw_payload: "payload_#{i}" * 100
          )
        end
      end

      before do
        pool.instance_variable_set(:@started, true)
      end

      it 'returns Immediate' do
        result = pool.dispatch_async(small_messages, deserializer)
        expect(result).to be_a(Karafka::Deserializing::Parallel::Immediate)
      end
    end

    context 'when total payload threshold is not met' do
      let(:tiny_messages) do
        Array.new(10) do
          instance_double(
            Karafka::Messages::Message,
            raw_payload: 'x'
          )
        end
      end

      before do
        pool.instance_variable_set(:@started, true)
      end

      it 'returns Immediate' do
        result = pool.dispatch_async(tiny_messages, deserializer)
        expect(result).to be_a(Karafka::Deserializing::Parallel::Immediate)
      end
    end

    context 'when messages have nil raw_payload' do
      let(:nil_payload_messages) do
        Array.new(10) do
          instance_double(
            Karafka::Messages::Message,
            raw_payload: nil
          )
        end
      end

      before do
        pool.instance_variable_set(:@started, true)
      end

      it 'returns Immediate due to threshold not met' do
        result = pool.dispatch_async(nil_payload_messages, deserializer)
        expect(result).to be_a(Karafka::Deserializing::Parallel::Immediate)
      end
    end
  end
end
