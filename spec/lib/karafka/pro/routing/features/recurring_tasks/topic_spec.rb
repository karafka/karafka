# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:topic) { build(:routing_topic) }

  describe '#recurring_tasks' do
    context 'when we use recurring_tasks without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.recurring_tasks.active?).to be(false)
      end
    end

    context 'when we use recurring_tasks with active status' do
      it 'expect to use proper active status' do
        topic.recurring_tasks(true)
        expect(topic.recurring_tasks.active?).to be(true)
      end
    end

    context 'when we use recurring_tasks multiple times with different values' do
      it 'expect to use proper active status' do
        topic.recurring_tasks(true)
        topic.recurring_tasks(false)
        expect(topic.recurring_tasks.active?).to be(true)
      end
    end
  end

  describe '#recurring_tasks?' do
    context 'when active' do
      before { topic.recurring_tasks(true) }

      it { expect(topic.recurring_tasks?).to be(true) }
    end

    context 'when not active' do
      before { topic.recurring_tasks(false) }

      it { expect(topic.recurring_tasks?).to be(false) }
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:recurring_tasks]).to eq(topic.recurring_tasks.to_h) }
  end
end
