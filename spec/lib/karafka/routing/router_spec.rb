require 'spec_helper'

RSpec.describe Karafka::Routing::Router do
<<<<<<< HEAD
  let(:topic) { "topic#{rand(1000)}".to_sym }
  let(:event) { double(topic: topic, message: {}.to_json) }

  subject { described_class.new(event) }

  describe '#call' do
    context 'when there is no controller that matches the topic' do
      before do
        expect(Karafka::Routing::Mapper)
          .to receive(:by_topics)
          .and_return({})
      end

      it 'should raise a NonMatchingTopicError' do
        expect { subject.call }.to raise_error(described_class::NonMatchingTopicError)
      end
    end

    context 'when there is a matching controller' do
      let(:controller) do
        ClassBuilder.inherit(Karafka::BaseController) do
          self.group = :group
          self.topic = :topic

          def perform
          end
        end
      end

      before do
        expect(Karafka::Routing::Mapper)
          .to receive(:by_topics)
          .and_return(topic => controller)
      end

      it 'should use it, assign params and call it' do
        expect_any_instance_of(controller)
          .to receive(:params=)

        expect_any_instance_of(controller)
          .to receive(:call)

        expect { subject.call }.to_not raise_error
      end
    end
  end
=======
  pending
>>>>>>> merge branch with reorg
end
