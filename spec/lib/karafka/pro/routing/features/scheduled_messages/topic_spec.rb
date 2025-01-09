# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:topic) { build(:routing_topic) }

  describe '#scheduled_messages' do
    context 'when we use scheduled_messages without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.scheduled_messages.active?).to be(false)
      end
    end

    context 'when we use scheduled_messages with active status' do
      it 'expect to use proper active status' do
        topic.scheduled_messages(true)
        expect(topic.scheduled_messages.active?).to be(true)
      end
    end

    context 'when we use scheduled_messages multiple times with different values' do
      it 'expect to use proper active status' do
        topic.scheduled_messages(true)
        topic.scheduled_messages(false)
        expect(topic.scheduled_messages.active?).to be(true)
      end
    end
  end

  describe '#scheduled_messages?' do
    context 'when active' do
      before { topic.scheduled_messages(true) }

      it { expect(topic.scheduled_messages?).to be(true) }
    end

    context 'when not active' do
      before { topic.scheduled_messages(false) }

      it { expect(topic.scheduled_messages?).to be(false) }
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:scheduled_messages]).to eq(topic.scheduled_messages.to_h) }
  end
end
