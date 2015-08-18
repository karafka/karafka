require 'spec_helper'

RSpec.describe Karafka::Connection::Event do
  let(:topic) { double }
  let(:message) { double }

  subject { described_class.new(topic, message) }

  describe '.initialize' do
    it 'should store both topic and message' do
      expect(subject.topic).to eq topic
      expect(subject.message).to eq message
    end
  end
end
