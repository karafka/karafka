require 'spec_helper'

RSpec.describe Karafka::Routing::Mapper do
<<<<<<< HEAD
  subject { described_class }

  let(:controller1) do
    ClassBuilder.inherit(Karafka::BaseController) do
      self.topic = :topic1
    end
  end

  let(:controller2) do
    ClassBuilder.inherit(Karafka::BaseController) do
      self.topic = :topic2
    end
  end

  describe '#validate' do
    let(:controllers) { double }

    it 'should validate groups and topics and then return input' do
      expect(subject)
        .to receive(:validate_key)
        .with(controllers, :group, described_class::DuplicatedGroupError)

      expect(subject)
        .to receive(:validate_key)
        .with(controllers, :topic, described_class::DuplicatedTopicError)

      expect(subject.send(:validate, controllers)).to eq controllers
    end
  end

  describe '#validate_key' do
    context 'when we dont have duplications' do
      let(:controllers) { [controller1, controller2] }
      let(:err) { StandardError }

      it 'should not raise an error' do
        expect { subject.send(:validate_key, controllers, :topic, err) }.not_to raise_error
      end
    end

    context 'when we have duplications' do
      let(:controller2) do
        ClassBuilder.inherit(Karafka::BaseController) do
          self.topic = :topic1
        end
      end

      let(:controllers) { [controller1, controller2] }
      let(:err) { StandardError }

      it 'should not raise an error' do
        expect { subject.send(:validate_key, controllers, :topic, err) }.to raise_error(err)
      end
    end
  end

  describe '#by_topics' do
    let(:controllers) { [controller1, controller2] }

    let(:topics_map) { { topic1: controller1, topic2: controller2 } }

    it 'should return a topic - controllers map' do
      expect(subject)
        .to receive(:controllers)
        .and_return(controllers)

      expect(subject.by_topics).to eq topics_map
    end
  end

  describe '#controllers' do
    context 'when they are already invoked' do
      let(:controllers) { double }

      before do
        subject.instance_variable_set(:'@controllers', controllers)
      end

      it 'should return what is already stored' do
        expect(subject.controllers).to eq controllers
      end
    end

    context 'when this is first invokation' do
      let(:descendants) { double }
      let(:validated_descendants) { double }

      before do
        subject.instance_variable_set(:'@controllers', nil)
      end

      it 'should load descendants and validate them' do
        expect(Karafka::BaseController)
          .to receive(:descendants)
          .and_return(descendants)

        expect(subject)
          .to receive(:validate)
          .and_return(validated_descendants)

        expect(subject.controllers).to eq validated_descendants
        # We check twice to check if it is stored
        expect(subject.controllers).to eq validated_descendants
      end
    end
  end
=======
  pending
>>>>>>> merge branch with reorg
end
