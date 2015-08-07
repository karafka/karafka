require 'spec_helper'

RSpec.describe Karafka::Router do
  let(:dummy_klass) do
    # fake class
    class DummyClass < Karafka::BaseController
      self.topic = 'A topic'
      def process
        'A process'
      end
      self
    end
  end

  let(:classes) { [dummy_klass] }
  let(:controller) { double }
  describe '#initialize' do
    it 'creates class once exists controller with needed topic' do
      allow(Karafka::BaseController).to receive(:descendants)
        .and_return(classes)
      expect(dummy_klass).to receive(:new).with('message').and_return(controller)
      expect(controller).to receive(:call)
      described_class.new('A topic', 'message')
    end

    it 'fails once there are no controllers with needed topic' do
      allow(Karafka::BaseController).to receive(:descendants)
        .and_return(classes)
      expect(classes).to receive(:detect).and_return(nil)
      expect { described_class.new('Not provided topic', 'message') }
        .to raise_error(Karafka::Router::UndefinedTopicError)
    end
  end
end
