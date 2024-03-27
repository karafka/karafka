# frozen_string_literal: true

RSpec.describe_current do
  subject(:deserialized) { described_class.new.call(data) }

  let(:data) { rand }

  describe '.call' do
    it 'expect to return what was given' do
      expect(deserialized).to eq(data)
    end
  end
end
