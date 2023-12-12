# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) do
    build(:routing_topic).tap do |topic|
      topic.singleton_class.prepend described_class
    end
  end

  describe '#periodic_job' do
    context 'when we use periodic_job without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.periodic_job.active?).to eq(false)
        expect(topic.periodic_job.frequency).to eq(5_000)
      end
    end

    context 'when used via the periodic alias without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.periodic.active?).to eq(false)
        expect(topic.periodic_job.frequency).to eq(5_000)
      end
    end

    context 'when we use periodic_job with active status' do
      it 'expect to use proper active status' do
        topic.periodic(true)
        expect(topic.periodic_job.active?).to eq(true)
      end
    end

    context 'when we use periodic_job multiple times with different values' do
      it 'expect to use proper active status' do
        topic.periodic(true)
        topic.periodic(false)
        expect(topic.periodic_job.active?).to eq(true)
        expect(topic.periodic_job.frequency).to eq(5_000)
      end
    end

    context 'when initialized only with frequency' do
      it 'expect to use proper active status and frequency' do
        topic.periodic(frequency: 2_500)
        expect(topic.periodic_job.active?).to eq(true)
        expect(topic.periodic_job.frequency).to eq(2_500)
      end
    end
  end

  describe '#periodic_job?' do
    context 'when active' do
      before { topic.periodic(true) }

      it { expect(topic.periodic_job?).to eq(true) }
    end

    context 'when not active' do
      before { topic.periodic(false) }

      it { expect(topic.periodic_job?).to eq(false) }
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:periodic_job]).to eq(topic.periodic_job.to_h) }
  end
end
