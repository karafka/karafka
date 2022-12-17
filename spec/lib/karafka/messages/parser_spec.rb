# frozen_string_literal: true

RSpec.describe_current do
  subject(:parser) { described_class.new }

  let(:message) { build(:messages_message) }

  it 'expect to call the message deserializer and return the deserialized payload' do
    expect(parser.call(message)).to eq({})
  end
end
