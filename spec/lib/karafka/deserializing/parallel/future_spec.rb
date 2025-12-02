# frozen_string_literal: true

RSpec.describe_current do
  before do
    unless RUBY_VERSION >= '4.0' && defined?(Ractor::Port)
      skip 'Requires Ruby 4.0+ with Ractor::Port'
    end
  end

  subject(:future) { described_class.new(result_port, batch_count) }

  let(:result_port) { instance_double(Ractor::Port) }
  let(:batch_count) { 2 }

  describe '#initialize' do
    it 'starts with retrieved? false' do
      expect(future.retrieved?).to be(false)
    end
  end

  describe '#retrieved?' do
    context 'when results have not been retrieved' do
      it 'returns false' do
        expect(future.retrieved?).to be(false)
      end
    end
  end

  describe '#retrieve' do
    context 'when results are available' do
      before do
        allow(result_port).to receive(:receive).and_return(
          { batch_index: 0, results: %w[result1 result2] },
          { batch_index: 1, results: ['result3'] }
        )
      end

      it 'collects results from result_port' do
        future.retrieve

        expect(result_port).to have_received(:receive).twice
      end

      it 'returns flattened results array' do
        results = future.retrieve

        expect(results).to eq(%w[result1 result2 result3])
      end

      it 'marks future as retrieved' do
        future.retrieve

        expect(future.retrieved?).to be(true)
      end
    end

    context 'when called multiple times' do
      before do
        allow(result_port).to receive(:receive).and_return(
          { batch_index: 0, results: %w[result1 result2] },
          { batch_index: 1, results: ['result3'] }
        )
      end

      it 'only retrieves once' do
        future.retrieve
        future.retrieve

        # Should only call receive twice (once for each batch), not four times
        expect(result_port).to have_received(:receive).twice
      end

      it 'returns cached results on subsequent calls' do
        first_results = future.retrieve
        second_results = future.retrieve

        expect(first_results).to eq(second_results)
      end
    end

    context 'when results contain errors' do
      let(:error_marker) { Karafka::Deserializing::Parallel::DESERIALIZATION_ERROR }

      before do
        allow(result_port).to receive(:receive).and_return(
          { batch_index: 0, results: [error_marker, 'result2'] },
          { batch_index: 1, results: ['result3'] }
        )
      end

      it 'includes error markers in results array' do
        results = future.retrieve

        expect(results[0]).to equal(error_marker)
        expect(results[1]).to eq('result2')
        expect(results[2]).to eq('result3')
      end
    end

    context 'when results arrive out of order' do
      before do
        # Results arrive in reverse order
        allow(result_port).to receive(:receive).and_return(
          { batch_index: 1, results: ['result3'] },
          { batch_index: 0, results: %w[result1 result2] }
        )
      end

      it 'correctly orders results by batch_index' do
        results = future.retrieve

        expect(results).to eq(%w[result1 result2 result3])
      end
    end
  end
end
