# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) { build(:routing_topic) }

  describe '#non_blocking_job' do
    context 'when we use non_blocking_job without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.long_running_job.active?).to be(false)
      end
    end

    context 'when we use non_blocking_job with active status' do
      it 'expect to use proper active status' do
        topic.non_blocking_job(true)
        expect(topic.long_running_job.active?).to be(true)
      end
    end

    context 'when we use non_blocking_job multiple times with different values' do
      it 'expect to use proper active status' do
        topic.non_blocking_job(true)
        topic.non_blocking_job(false)
        expect(topic.long_running_job.active?).to be(true)
      end
    end
  end

  describe '#long_running_job?' do
    context 'when active' do
      before { topic.non_blocking_job(true) }

      it { expect(topic.long_running_job?).to be(true) }
    end

    context 'when not active' do
      before { topic.non_blocking_job(false) }

      it { expect(topic.long_running_job?).to be(false) }
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:long_running_job]).to eq(topic.non_blocking_job.to_h) }
  end
end
