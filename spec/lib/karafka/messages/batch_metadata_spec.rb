# frozen_string_literal: true

RSpec.describe_current do
  subject(:metadata) { described_class.new }

  let(:rand_value) { rand }

  describe '#topic' do
    before { metadata['topic'] = rand_value }

    it { expect(metadata.topic).to eq rand_value }
  end

  describe '#size' do
    before { metadata['size'] = rand_value }

    it { expect(metadata.size).to eq rand_value }
  end

  describe '#partition' do
    before { metadata['partition'] = rand_value }

    it { expect(metadata.partition).to eq rand_value }
  end

  describe '#last_offset' do
    before { metadata['last_offset'] = rand_value }

    it { expect(metadata.last_offset).to eq rand_value }
  end

  describe '#deserializer' do
    before { metadata['deserializer'] = rand_value }

    it { expect(metadata.deserializer).to eq rand_value }
  end

  describe '#first_offset' do
    before { metadata['first_offset'] = rand_value }

    it { expect(metadata.first_offset).to eq rand_value }
  end

  describe '#scheduled_at' do
    before { metadata['scheduled_at'] = rand_value }

    it { expect(metadata.scheduled_at).to eq rand_value }
  end

  describe '#consumption_lag' do
    before { metadata['consumption_lag'] = rand_value }

    it { expect(metadata.consumption_lag).to eq rand_value }
  end

  describe '#processing_lag' do
    before { metadata['processing_lag'] = rand_value }

    it { expect(metadata.processing_lag).to eq rand_value }
  end
end
