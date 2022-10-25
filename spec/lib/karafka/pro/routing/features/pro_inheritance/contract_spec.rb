# frozen_string_literal: true

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) { { consumer: consumer } }

  context 'when config is valid' do
    let(:consumer) { Class.new(Karafka::Pro::BaseConsumer) }

    it { expect(check).to be_success }
  end

  context 'when consumer is not coming from pro base' do
    let(:consumer) { Class.new(Karafka::BaseConsumer) }

    it { expect(check).not_to be_success }
  end
end
