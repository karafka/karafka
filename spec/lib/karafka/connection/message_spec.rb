require 'spec_helper'

RSpec.describe Karafka::Connection::Message do
  let(:topic) { double }
  let(:content) { double }

  subject { described_class.new(topic, content) }

  describe '.initialize' do
    it 'stores both topic and content' do
      expect(subject.topic).to eq topic
      expect(subject.content).to eq content
    end
  end
end
