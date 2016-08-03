require 'spec_helper'

RSpec.describe Karafka::Routing::Builder do
  subject(:builder) { described_class.instance }

  let(:route) { Karafka::Routing::Route.new }

  Karafka::Routing::Builder::ROUTE_OPTIONS.each do |option|
    describe "##{option}" do
      let(:value) { double }

      before do
        builder.instance_variable_set(:@current_route, route)
      end

      it "expect to assign #{option} to current route" do
        expect(route)
          .to receive(:"#{option}=")
          .with(value)

        builder.send(option, value)
      end
    end
  end

  describe '#topic' do
    let(:topic) { rand }

    before { route }

    it 'expect to create a new route, assign to it a topic and eval' do
      expect(Karafka::Routing::Route).to receive(:new).and_return(route)
      expect(route).to receive(:topic=).with(topic)
      expect(builder).to receive(:store!)

      expect { |block| builder.topic(topic, &block) }.to yield_control
    end
  end

  describe '#draw' do
    it 'expect to eval' do
      expect { |block| builder.draw(&block) }.to yield_control
    end
  end

  describe '#store!' do
    before do
      builder.instance_variable_set(:@current_route, route)
    end

    it 'expect to build, validate and save current route' do
      expect(route).to receive(:build)
      expect(route).to receive(:validate!)
      expect(builder).to receive(:<<).with(route)
      expect(builder).to receive(:validate!)
        .with(:topic, Karafka::Errors::DuplicatedTopicError)
      expect(builder).to receive(:validate!)
        .with(:group, Karafka::Errors::DuplicatedGroupError)

      builder.send(:store!)
    end
  end

  describe '#validate!' do
    let(:attribute) { :topic }
    let(:topic) { rand.to_s }
    let(:error) { StandardError }

    context 'when there is duplication of elements with given attribute' do
      before do
        builder << route.class.new.tap { |route| route.topic = topic }
        builder << route.class.new.tap { |route| route.topic = topic }
      end

      it { expect { builder.send(:validate!, attribute, error) }.to raise_error(error) }
    end

    context 'when there are no attributes' do
      before { builder.clear }

      it { expect { builder.send(:validate!, attribute, error) }.not_to raise_error }
    end

    context 'when there are objects without duplication of attribute' do
      before do
        builder << route.class.new.tap { |route| route.topic = topic }
        builder << route.class.new.tap { |route| route.topic = rand.to_s }
      end

      it { expect { builder.send(:validate!, attribute, error) }.not_to raise_error }
    end
  end
end
