# frozen_string_literal: true

require 'karafka/pro/base_consumer_extensions'

RSpec.describe_current do
  subject(:consumer) do
    Karafka::BaseConsumer.new.tap do |instance|
      instance.singleton_class.include Karafka::Pro::BaseConsumerExtensions
    end
  end

  describe '#revoked? and #on_revoked' do
    context 'when partition was not revoked' do
      it { expect(consumer.revoked?).to eq(false) }
    end

    context 'when partition was revoked' do
      before { consumer.on_revoked }

      it { expect(consumer.revoked?).to eq(true) }
    end
  end
end
