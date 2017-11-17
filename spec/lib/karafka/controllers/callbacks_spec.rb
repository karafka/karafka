# frozen_string_literal: true

RSpec.describe Karafka::Controllers::Callbacks do
  subject(:base_controller) { working_class.new }

  let(:topic_name) { "topic#{rand}" }
  let(:backend) { :inline }
  let(:responder_class) { nil }
  let(:consumer_group) { Karafka::Routing::ConsumerGroup.new(rand.to_s) }
  let(:topic) do
    topic = Karafka::Routing::Topic.new(topic_name, consumer_group)
    topic.controller = Class.new(Karafka::BaseController)
    topic.controller.include described_class
    topic.backend = backend
    topic.responder = responder_class
    topic
  end
  let(:working_class) do
    described_scope = described_class

    ClassBuilder.inherit(Karafka::BaseController) do
      include Karafka::Backends::Inline
      include Karafka::Controllers::Responders
      include described_scope

      def consume
        self
      end
    end
  end

  before { working_class.topic = topic }

  describe '#consume' do
    let(:working_class) { ClassBuilder.inherit(Karafka::BaseController) }

    it { expect { base_controller.send(:consume) }.to raise_error NotImplementedError }
  end

  context 'when we want to use after_fetched callback' do
    describe '#call' do
      context 'when there are no callbacks' do
        it 'just schedules' do
          expect(base_controller).to receive(:process)

          base_controller.call
        end
      end
    end

    context 'when we have a block based after_fetched' do
      let(:backend) { :inline }

      context 'when it throws abort to halt' do
        subject(:base_controller) do
          described_scope = described_class

          ClassBuilder.inherit(Karafka::BaseController) do
            include Karafka::Backends::Inline
            include described_scope

            after_fetched do
              throw(:abort)
            end

            def consume
              self
            end
          end.new
        end

        it 'does not consume' do
          expect(base_controller).not_to receive(:consume)

          base_controller.call
        end
      end

      context 'when it does not throw abort to halt' do
        subject(:base_controller) do
          described_scope = described_class

          ClassBuilder.inherit(Karafka::BaseController) do
            include Karafka::Backends::Inline
            include described_scope

            after_fetched do
              true
            end

            def consume
              self
            end
          end.new
        end

        let(:params) { double }

        it 'executes' do
          expect(base_controller).to receive(:process)
          base_controller.call
        end
      end
    end

    context 'when we have a method based after_fetched' do
      let(:backend) { :inline }

      context 'when it throws abort to halt' do
        subject(:base_controller) do
          described_scope = described_class

          ClassBuilder.inherit(Karafka::BaseController) do
            include described_scope

            after_fetched :method

            def consume
              self
            end

            def method
              throw(:abort)
            end
          end.new
        end

        it 'does not consume' do
          expect(base_controller).not_to receive(:consume)

          base_controller.call
        end
      end

      context 'when it does not return false' do
        subject(:base_controller) do
          described_scope = described_class

          ClassBuilder.inherit(Karafka::BaseController) do
            include Karafka::Backends::Inline
            include described_scope

            after_fetched :method

            def consume
              self
            end

            def method
              true
            end
          end.new
        end

        it 'schedules to a backend' do
          expect(base_controller).to receive(:consume)

          base_controller.call
        end
      end
    end
  end
end
