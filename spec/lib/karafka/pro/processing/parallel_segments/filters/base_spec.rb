# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:filter) do
    described_class.new(
      segment_id: segment_id,
      partitioner: partitioner,
      reducer: reducer
    )
  end

  let(:segment_id) { 1 }
  let(:partitioner) { ->(message) { message.key } }
  let(:reducer) { ->(parallel_key) { parallel_key.to_s.sum % 2 } }

  describe '#initialize' do
    it 'sets the segment_id' do
      expect(filter.instance_variable_get(:@segment_id)).to eq(segment_id)
    end

    it 'sets the partitioner' do
      expect(filter.instance_variable_get(:@partitioner)).to eq(partitioner)
    end

    it 'sets the reducer' do
      expect(filter.instance_variable_get(:@reducer)).to eq(reducer)
    end

    it 'calls super' do
      # Base is initialized with default values
      expect(filter.applied?).to be(false)
    end

    context 'with different values' do
      let(:segment_id) { 5 }
      let(:partitioner) { ->(message) { message.headers['custom_key'] } }
      let(:reducer) { ->(parallel_key) { parallel_key.hash % 10 } }

      it 'sets different segment_id correctly' do
        expect(filter.instance_variable_get(:@segment_id)).to eq(5)
      end

      it 'sets different partitioner correctly' do
        expect(filter.instance_variable_get(:@partitioner)).to eq(partitioner)
      end

      it 'sets different reducer correctly' do
        expect(filter.instance_variable_get(:@reducer)).to eq(reducer)
      end
    end
  end

  describe 'inheritance hierarchy' do
    it 'inherits from Processing::Filters::Base' do
      expect(described_class.superclass).to eq(Karafka::Pro::Processing::Filters::Base)
    end
  end

  describe 'required methods' do
    it 'does not implement apply! method' do
      expect { filter.apply!([]) }.to raise_error(NotImplementedError)
    end

    it 'inherits applied? method from parent' do
      expect(filter.applied?).to be(false)
    end
  end

  describe 'argument validation' do
    context 'with missing required arguments' do
      it 'raises an error when segment_id is missing' do
        expect do
          described_class.new(
            partitioner: partitioner,
            reducer: reducer
          )
        end.to raise_error(ArgumentError)
      end

      it 'raises an error when partitioner is missing' do
        expect do
          described_class.new(
            segment_id: segment_id,
            reducer: reducer
          )
        end.to raise_error(ArgumentError)
      end

      it 'raises an error when reducer is missing' do
        expect do
          described_class.new(
            segment_id: segment_id,
            partitioner: partitioner
          )
        end.to raise_error(ArgumentError)
      end
    end

    context 'with invalid argument types' do
      it 'accepts any type for segment_id' do
        expect do
          described_class.new(
            segment_id: 'string_id',
            partitioner: partitioner,
            reducer: reducer
          )
        end.not_to raise_error
      end

      it 'raises no error when partitioner is not callable' do
        # In a real scenario this would fail later, but the constructor doesn't validate
        # callability
        expect do
          described_class.new(
            segment_id: segment_id,
            partitioner: 'not_callable',
            reducer: reducer
          )
        end.not_to raise_error
      end

      it 'raises no error when reducer is not callable' do
        # In a real scenario this would fail later, but the constructor doesn't validate
        # callability
        expect do
          described_class.new(
            segment_id: segment_id,
            partitioner: partitioner,
            reducer: 'not_callable'
          )
        end.not_to raise_error
      end
    end
  end
end
