# frozen_string_literal: true

RSpec.describe_current do
  subject(:proxy) { described_class.new(config) }

  let(:config) { double('config') }

  describe '#initialize' do
    it 'initializes producer_initialization_block as empty lambda' do
      expect(proxy.producer_initialization_block).to be_a(Proc)
      # Verify it's a no-op by calling it with a test object
      test_obj = double('test')
      expect { proxy.producer_initialization_block.call(test_obj) }.not_to raise_error
    end
  end

  describe '#producer' do
    context 'when called with a block' do
      it 'stores the block' do
        test_block = proc { |_| }
        proxy.producer(&test_block)

        expect(proxy.producer_initialization_block).to eq(test_block)
      end
    end

    context 'when called with an instance' do
      it 'delegates to config.producer=' do
        producer_instance = instance_double(WaterDrop::Producer)
        allow(config).to receive(:producer=)

        proxy.producer(producer_instance)

        expect(config).to have_received(:producer=).with(producer_instance)
      end
    end
  end

  describe '#method_missing' do
    it 'delegates method calls to config' do
      allow(config).to receive(:some_method).with('arg1', 'arg2').and_return('result')

      result = proxy.some_method('arg1', 'arg2')

      expect(result).to eq('result')
    end

    it 'delegates methods with blocks to config' do
      allow(config).to receive(:some_method).and_yield('value')

      yielded_value = nil
      proxy.some_method { |val| yielded_value = val }

      expect(yielded_value).to eq('value')
    end
  end

  describe '#respond_to_missing?' do
    it 'returns true if config responds to the method' do
      allow(config).to receive(:respond_to?).and_return(true)

      expect(proxy.respond_to?(:some_method)).to be true
    end

    it 'returns false if config does not respond to the method' do
      allow(config).to receive(:respond_to?).and_return(false)

      expect(proxy.respond_to?(:unknown_method)).to be false
    end
  end
end
