require 'spec_helper'

RSpec.describe Karafka::Aspects::Formatter do
  describe '#apply' do
    let(:options) { { method: :run, topic: 'topic', result: 'message' } }
    let(:args) { double }
    let(:result) { double }
    let(:topic) { double }
    let(:method) { double }
    subject { described_class.new(options, args, result) }

    it 'formats message to send' do
      expect(subject.apply)
        .to eq(
          topic: options[:topic],
          method: options[:method],
          message: result,
          args: args
        )
    end
  end
end
