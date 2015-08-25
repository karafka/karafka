require 'spec_helper'

RSpec.describe Karafka::Connection::Consumer do
  let(:controller) do
    ClassBuilder.inherit(Karafka::BaseController) do
      self.group = rand
      self.topic = rand

      def perform; end
    end
  end

  describe '#fetch' do
    let(:listener) { Karafka::Connection::Listener.new(controller) }
    let(:listeners) { [listener] }
    let(:event) { double }
    let(:built_controller) { double }
    let(:router) { Karafka::Routing::Router.new(event) }
    let(:async_scope) { listener }

    it 'should use fetch on an each listener and route the request' do
      expect(subject)
        .to receive(:listeners)
        .and_return(listeners)

      expect(listener)
        .to receive(:controller)
        .and_return(controller)
        .at_least(:once)

      expect(listener)
        .to receive(:async)
        .and_return(async_scope)

      expect(async_scope)
        .to receive(:fetch_loop)

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

  describe '#message_action' do
    let(:listener) { double }
    let(:message_proc) { subject.send(:message_action, listener) }
    let(:incoming_message) { double }
    let(:router) { double }

    it 'should be a proc' do
      expect(message_proc).to be_a Proc
    end

    it 'should build and route to controller based on message' do
      expect(listener)
        .to receive(:controller)
        .and_return(controller)

      expect(Karafka::Routing::Router)
        .to receive(:new)
        .with(incoming_message)
        .and_return(router)

      expect(router)
        .to receive_message_chain(:build, :call)

      message_proc.call(incoming_message)
    end
  end
end
