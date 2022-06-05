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
    let(:created_at) { 2.days.ago }
    let(:processed_at) { 1.days.ago }

    before do
      metadata['created_at'] = created_at
      metadata['processed_at'] = processed_at
    end

    it 'expect to calculate it as a distance in between message creation time and processing' do
      expect(metadata.consumption_lag).to eq(((processed_at - created_at) * 1_000).round)
    end
  end

  describe '#processing_lag' do
    let(:scheduled_at) { 2.days.ago }
    let(:processed_at) { 1.days.ago }

    before do
      metadata['scheduled_at'] = scheduled_at
      metadata['processed_at'] = processed_at
    end

    it 'expect to calculate it as a distance in between message schedule time and processing' do
      expect(metadata.processing_lag).to eq(((processed_at - scheduled_at) * 1_000).round)
    end
  end
end
