# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:config) do
    described_class.new(
      active: active,
      count: count,
      partitioner: partitioner,
      reducer: reducer,
      merge_key: merge_key
    )
  end

  let(:active) { true }
  let(:count) { 5 }
  let(:partitioner) { ->(message) { message.key } }
  let(:reducer) { ->(messages) { messages.last } }
  let(:merge_key) { 'user_id' }

  describe '#active?' do
    context 'when active' do
      it { expect(config.active?).to be(true) }
    end

    context 'when not active' do
      let(:active) { false }

      it { expect(config.active?).to be(false) }
    end
  end

  describe 'struct attributes' do
    describe '#count' do
      it { expect(config.count).to eq(5) }
    end

    describe '#partitioner' do
      it { expect(config.partitioner).to be_a(Proc) }
    end

    describe '#reducer' do
      it { expect(config.reducer).to be_a(Proc) }
    end

    describe '#merge_key' do
      it { expect(config.merge_key).to eq('user_id') }
    end
  end
end
