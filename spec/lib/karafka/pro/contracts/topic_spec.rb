# frozen_string_literal: true

require 'karafka/pro/base_consumer'
require 'karafka/pro/contracts/base'
require 'karafka/pro/contracts/topic'

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      consumer: Class.new(Karafka::Pro::BaseConsumer),
      virtual_partitions: {
        active: true,
        partitioner: ->(_) { 1 },
        max_partitions: 2
      }
    }
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when virtual partitions max_partitions is too low' do
    before { config[:virtual_partitions][:max_partitions] = 0 }

    it { expect(check).not_to be_success }
  end

  context 'when virtual partitions are active but no partitioner' do
    before { config[:virtual_partitions][:partitioner] = nil }

    it { expect(check).not_to be_success }
  end

  context 'when consumer inherits from the base consumer' do
    before { config[:consumer] = Class.new(Karafka::BaseConsumer) }

    it { expect(check).not_to be_success }
  end
end
