# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:expirer) { described_class.new(500) }

  let(:messages) { [build(:messages_message)] }

  context 'when all messages are fresh' do
    it 'expect not to filter' do
      expect { expirer.apply!(messages) }.not_to(change { messages })
    end

    it 'expect not to apply' do
      expirer.apply!(messages)
      expect(expirer.applied?).to be(false)
    end

    it 'expect to always skip' do
      expirer.apply!(messages)
      expect(expirer.action).to eq(:skip)
    end
  end

  context 'when there is a message older than ttl' do
    let(:older) { build(:messages_message, timestamp: Time.now.utc - 2) }
    let(:newer) { build(:messages_message, timestamp: Time.now.utc) }

    let(:messages) { [older, newer] }

    it 'expect to filter' do
      expirer.apply!(messages)
      expect(messages).to eq([newer])
    end

    it 'expect to always skip' do
      expirer.apply!(messages)
      expect(expirer.action).to eq(:skip)
    end

    it 'expect to apply' do
      expirer.apply!(messages)
      expect(expirer.applied?).to be(true)
    end
  end
end
