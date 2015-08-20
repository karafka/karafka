require 'spec_helper'

RSpec.describe Karafka::Connection::Consumer do
  let(:controller) do
    ClassBuilder.inherit(Karafka::BaseController) do
      self.group = rand
      self.topic = rand

      def perform; end
    end
  end

  describe '#call' do
    it 'should loop with the fetch' do
      expect(subject)
        .to receive(:loop)
        .and_yield

      expect(subject)
        .to receive(:fetch)

      subject.call
    end
  end

  describe '#fetch' do
    let(:listener) { Karafka::Connection::Listener.new(controller) }
    let(:listeners) { [listener] }
    let(:event) { double }
    let(:built_controller) { double }
    let(:router) { Karafka::Routing::Router.new(event) }

    it 'should use fetch on an each listener and route the request' do
      expect(listener)
        .to receive(:fetch)
        .and_yield(event)

      expect(subject)
        .to receive(:listeners)
        .and_return(listeners)

      expect(Karafka::Routing::Router)
        .to receive(:new)
        .with(event)
        .and_return(router)

      expect(router)
        .to receive(:build)
        .and_return(built_controller)

      expect(built_controller)
        .to receive(:call)

      subject.send(:fetch)
    end
  end

  describe '#listeners' do
    let(:controllers) { [controller] }
    let(:listener) { double }

    before do
      expect(Karafka::Routing::Mapper)
        .to receive(:controllers)
        .and_return(controllers)

      expect(Karafka::Connection::Listener)
        .to receive(:new)
        .with(controller)
        .and_return(listener)
    end

    it 'should create new listeners based on the controllers' do
      expect(subject.send(:listeners)).to eq [listener]
    end
  end
end
