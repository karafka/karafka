# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:topic) { build(:routing_topic) }

  describe '#long_running_job' do
    context 'when we use long_running_job without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.long_running_job.active?).to be(false)
      end
    end

    context 'when we use long_running_job with active status' do
      it 'expect to use proper active status' do
        topic.long_running_job(true)
        expect(topic.long_running_job.active?).to be(true)
      end
    end

    context 'when we use long_running_job multiple times with different values' do
      it 'expect to use proper active status' do
        topic.long_running_job(true)
        topic.long_running_job(false)
        expect(topic.long_running_job.active?).to be(true)
      end
    end
  end

  describe '#long_running_job?' do
    context 'when active' do
      before { topic.long_running_job(true) }

      it { expect(topic.long_running_job?).to be(true) }
    end

    context 'when not active' do
      before { topic.long_running_job(false) }

      it { expect(topic.long_running_job?).to be(false) }
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:long_running_job]).to eq(topic.long_running_job.to_h) }
  end
end
