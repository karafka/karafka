# frozen_string_literal: true

RSpec.describe Karafka::Params::Metadata do
  subject(:metadata) { described_class.new }

  let(:rand_value) { rand }

  describe '#topic' do
    before { metadata['topic'] = rand_value }

    it { expect(metadata.topic).to eq rand_value }
  end

  describe '#batch_size' do
    before { metadata['batch_size'] = rand_value }

    it { expect(metadata.batch_size).to eq rand_value }
  end

  describe '#partition' do
    before { metadata['partition'] = rand_value }

    it { expect(metadata.partition).to eq rand_value }
  end

  describe '#offset_lag' do
    before { metadata['offset_lag'] = rand_value }

    it { expect(metadata.offset_lag).to eq rand_value }
  end

  describe '#last_offset' do
    before { metadata['last_offset'] = rand_value }

    it { expect(metadata.last_offset).to eq rand_value }
  end

  describe '#highwater_mark_offset' do
    before { metadata['highwater_mark_offset'] = rand_value }

    it { expect(metadata.highwater_mark_offset).to eq rand_value }
  end

  describe '#first_offset' do
    before { metadata['first_offset'] = rand_value }

    it { expect(metadata.first_offset).to eq rand_value }
  end

  describe '#unknown_last_offset?' do
    before { metadata['unknown_last_offset'] = rand_value }

    it { expect(metadata.unknown_last_offset?).to eq rand_value }
  end
end
