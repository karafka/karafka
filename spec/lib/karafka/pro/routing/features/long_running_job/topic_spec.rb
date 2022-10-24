# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) do
    build(:routing_topic).tap do |topic|
      topic.singleton_class.prepend described_class
    end
  end

  describe '#long_running_job' do
    context 'when we use long_running_job without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.long_running_job.active?).to eq(false)
      end
    end

    context 'when we use long_running_job with active status' do
      it 'expect to use proper active status' do
        topic.long_running_job(true)
        expect(topic.long_running_job.active?).to eq(true)
      end
    end

    context 'when we use long_running_job multiple times with different values' do
      it 'expect to use proper active status' do
        topic.long_running_job(true)
        topic.long_running_job(false)
        expect(topic.long_running_job.active?).to eq(true)
      end
    end
  end

  describe '#long_running_job?' do
    context 'when active' do
      before { topic.long_running_job(true) }

      it { expect(topic.long_running_job?).to eq(true) }
    end

    context 'when not active' do
      before { topic.long_running_job(false) }

      it { expect(topic.long_running_job?).to eq(false) }
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:long_running_job]).to eq(topic.long_running_job.to_h) }
  end
end
