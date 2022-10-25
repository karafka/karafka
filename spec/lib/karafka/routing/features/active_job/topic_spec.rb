# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) do
    build(:routing_topic).tap do |topic|
      topic.singleton_class.prepend described_class
    end
  end

  describe '#active_job' do
    context 'when we use active_job without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.active_job.active?).to eq(false)
      end
    end

    context 'when we use active_job with active status' do
      it 'expect to use proper active status' do
        topic.active_job(true)
        expect(topic.active_job.active?).to eq(true)
      end
    end

    context 'when we use active_job multiple times with different values' do
      it 'expect to use proper active status' do
        topic.active_job(true)
        topic.active_job(false)
        expect(topic.active_job.active?).to eq(true)
      end
    end
  end

  describe '#active_job?' do
    context 'when active' do
      before { topic.active_job(true) }

      it { expect(topic.active_job?).to eq(true) }
    end

    context 'when not active' do
      before { topic.active_job(false) }

      it { expect(topic.active_job?).to eq(false) }
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:active_job]).to eq(topic.active_job.to_h) }
  end
end
