require 'spec_helper'

RSpec.describe Karafka::Connection::Consumer do
  let(:controller_class) do
    ClassBuilder.inherit(Karafka::BaseController) do
      self.group = rand
      self.topic = rand

      def perform; end
    end
  end

  subject { described_class.new }

  describe '#consume' do
    let(:raw_message_value) { rand }
    let(:raw_message) { double(value: raw_message_value) }
    let(:message) { double }
    let(:builder) { Karafka::Routing::Router.new(nil) }
    let(:controller_instance) { double }

    it 'should route to a proper controller and call it' do
      expect(Karafka::Connection::Message)
        .to receive(:new)
        .with(controller_class.topic, raw_message_value)
        .and_return(message)

      expect(Karafka::Routing::Router)
        .to receive(:new)
        .with(message)
        .and_return(builder)

      expect(builder)
        .to receive(:build)
        .and_return(controller_instance)

      expect(controller_instance)
        .to receive(:call)

      subject.consume(controller_class, raw_message)
    end
  end
end
