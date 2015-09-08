require 'spec_helper'

RSpec.describe Karafka::Routing::Router do
  subject { described_class.new(message) }

  describe '#build' do
    let(:topic) { "topic#{rand(1000)}".to_sym }
    let(:message) { double(topic: topic, content: {}.to_json) }
    context 'when there is no controller that matches the topic' do
      before do
        expect(Karafka::Routing::Mapper)
          .to receive(:by_topics)
          .and_return({})
      end

      it 'should raise a NonMatchingTopicError' do
        expect { subject.build }
          .to raise_error(described_class::NonMatchingTopicError)
      end
    end

    context 'when there is a matching controller' do
      let(:another_controller) do
        ClassBuilder.inherit(Karafka::BaseController) do
          self.group = :group_2
          self.topic = :topic_2

          def perform
            self
          end
        end
      end
      before do
        expect(Karafka::Routing::Mapper)
          .to receive(:by_topics)
          .and_return(topic => another_controller)
      end
      it 'should use it, assign params and return controller' do
        expect_any_instance_of(another_controller)
          .to receive(:params=)

        expect(subject.build).to be_a(another_controller)
      end
    end
  end
end
