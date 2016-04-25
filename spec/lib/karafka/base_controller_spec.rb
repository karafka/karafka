require 'spec_helper'

RSpec.describe Karafka::BaseController do
  let(:working_class) do
    ClassBuilder.inherit(described_class) do
      def perform
        self
      end
    end
  end

  subject { ClassBuilder.inherit(described_class) }

  context 'instance methods and behaviours' do
    subject { working_class.new }

    describe '#schedule' do
      context 'when there are no callbacks' do
        it 'just schedules via perform_async' do
          expect(subject).to receive(:perform_async)

          subject.schedule
        end
      end
    end

    describe '#params=' do
      let(:message) { double }
      let(:params) { double }

      it 'creates params instance and assign it' do
        expect(Karafka::Params::Params)
          .to receive(:build)
          .with(
            message,
            subject
          )
          .and_return(params)

        subject.params = message

        expect(subject.instance_variable_get(:@params)).to eq params
      end
    end

    describe '#params' do
      let(:params) { Karafka::Params::Params.build({}, subject) }

      before do
        subject.instance_variable_set(:@params, params)
      end

      it 'retrieves params data' do
        expect(params)
          .to receive(:retrieve)
          .and_return(params)

        expect(subject.send(:params)).to eq params
      end
    end

    describe '#perform_async' do
      context 'when we want to perform async stuff' do
        let(:params) { double }
        let(:interchanger) { double }
        let(:interchanged_load_params) { double }
        let(:worker) { double }
        let(:topic) { rand.to_s }

        before do
          subject.interchanger = interchanger
          subject.worker = worker
          subject.topic = topic
        end

        it 'enqueue perform function' do
          subject.instance_variable_set :@params, params

          expect(subject.interchanger)
            .to receive(:load)
            .with(params)
            .and_return(interchanged_load_params)

          expect(worker)
            .to receive(:perform_async)
            .with(topic, interchanged_load_params)

          subject.send :perform_async
        end
      end
    end

    context 'when we have a block based before_enqueue' do
      context 'and it returns false' do
        subject do
          ClassBuilder.inherit(described_class) do
            before_enqueue do
              false
            end

            def perform
              self
            end
          end.new
        end

        it 'does not enqueue' do
          expect(subject).not_to receive(:enqueue)

          subject.schedule
        end
      end

      context 'and it does not return false' do
        subject do
          ClassBuilder.inherit(described_class) do
            before_enqueue do
              true
            end

            def perform
              self
            end
          end.new
        end

        let(:params) { double }

        it 'executes perform_async' do
          expect(subject).to receive(:perform_async)

          subject.schedule
        end
      end
    end

    context 'when we have a method based before_enqueue' do
      context 'and it returns false' do
        subject do
          ClassBuilder.inherit(described_class) do
            before_enqueue :method

            def perform
              self
            end

            def method
              false
            end
          end.new
        end

        it 'does not enqueue' do
          expect(subject).not_to receive(:enqueue)

          subject.schedule
        end
      end

      context 'and it does not return false' do
        subject do
          ClassBuilder.inherit(described_class) do
            before_enqueue :method

            def perform
              self
            end

            def method
              true
            end
          end.new
        end

        it 'enqueues with perform_async' do
          expect(subject).to receive(:perform_async)

          subject.schedule
        end
      end
    end
  end
end
