# frozen_string_literal: true

RSpec.describe_current do
  subject(:distributor) { described_class.new }

  describe '#call' do
    context 'when there is 1 message' do
      it 'returns a single batch' do
        result = distributor.call(%w[a], 4)
        expect(result).to eq([%w[a]])
      end
    end

    context 'when there are fewer messages than workers' do
      it 'returns a single batch' do
        result = distributor.call(%w[a b], 4)
        expect(result).to eq([%w[a b]])
      end
    end

    context 'when messages divide evenly across workers' do
      it 'returns equal-sized batches' do
        payloads = Array.new(100) { |i| "msg_#{i}" }
        result = distributor.call(payloads, 2)

        # 2×2 = 4 chunks, but 100/50 = 2 max → 2 chunks of 50
        expect(result.size).to eq(2)
        expect(result.flatten.size).to eq(100)
        expect(result.map(&:size)).to eq([50, 50])
      end
    end

    context 'with a large batch' do
      it 'creates 2×workers chunks respecting min_payloads' do
        payloads = Array.new(1000) { |i| "msg_#{i}" }
        result = distributor.call(payloads, 4)

        # 2×4 = 8 chunks, 1000/50 = 20 max, min(8, 20) = 8
        expect(result.size).to eq(8)
        expect(result.flatten.size).to eq(1000)
      end
    end

    context 'when min_payloads limits chunk count' do
      it 'does not create chunks smaller than min_payloads' do
        payloads = Array.new(200) { |i| "msg_#{i}" }
        result = distributor.call(payloads, 10, min_payloads: 50)

        # 2×10 = 20 chunks, but 200/50 = 4 max → 4 chunks of 50
        expect(result.size).to eq(4)
        expect(result.map(&:size)).to all(be >= 50)
      end
    end

    context 'with custom min_payloads' do
      it 'respects the provided minimum' do
        payloads = Array.new(500) { |i| "msg_#{i}" }
        result = distributor.call(payloads, 5, min_payloads: 100)

        # 2×5 = 10 chunks, but 500/100 = 5 max → 5 chunks of 100
        expect(result.size).to eq(5)
        expect(result.map(&:size)).to all(be >= 100)
      end
    end

    context 'when batch is very small' do
      it 'returns a single batch when below min_payloads' do
        payloads = Array.new(30) { |i| "msg_#{i}" }
        result = distributor.call(payloads, 4)

        # 30/50 = 0, max(0,1) = 1 chunk
        expect(result.size).to eq(1)
        expect(result.first.size).to eq(30)
      end
    end
  end
end
