RSpec.describe Karafka::BaseController do
  let(:working_class) do
    ClassBuilder.inherit(described_class) do
      def perform
        self
      end
    end
  end

  context 'instance methods and behaviours' do
    subject(:base_controller) { working_class.new }

    describe '#perform' do
      context 'when perform method is defined' do
        it { expect { base_controller.perform }.not_to raise_error }
      end

      context 'when perform method is not defined' do
        let(:working_class) { ClassBuilder.inherit(described_class) }
        it { expect { base_controller.perform }.to raise_error NotImplementedError }
      end
    end

    describe '#schedule' do
      context 'when there are no callbacks' do
        context 'and we dont want to perform inline' do
          it 'just schedules via perform_async' do
            expect(base_controller).to receive(:perform_async)

            base_controller.schedule
          end
        end

        context 'and we want to perform inline' do
          before do
            expect(base_controller)
              .to receive(:inline)
              .and_return(true)
          end

          it 'just expect to run with perform_inline' do
            expect(base_controller).to receive(:perform_inline)

            base_controller.schedule
          end
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
            base_controller
          )
          .and_return(params)

        base_controller.params = message

        expect(base_controller.instance_variable_get(:@params)).to eq params
      end
    end

    describe '#params' do
      let(:params) { Karafka::Params::Params.build({}, base_controller) }

      before do
        base_controller.instance_variable_set(:@params, params)
      end

      it 'retrieves params data' do
        expect(params)
          .to receive(:retrieve)
          .and_return(params)

        expect(base_controller.send(:params)).to eq params
      end
    end

    describe '#respond_with' do
      before { base_controller.responder = responder_class }

      context 'when there is no responder for a given controller' do
        let(:responder_class) { nil }
        let(:error) { Karafka::Errors::ResponderMissing }

        it { expect { base_controller.send(:respond_with, {}) }.to raise_error(error) }
      end

      context 'when there is responder for a given controller' do
        let(:responder_class) { Karafka::BaseResponder }
        let(:responder) { instance_double(responder_class) }
        let(:data) { [rand, rand] }

        before do
          expect(responder_class)
            .to receive(:new).and_return(responder)
        end

        it 'expect to use responder to respond with provided data' do
          expect(responder).to receive(:call).with(data)
          base_controller.send(:respond_with, data)
        end
      end
    end

    describe '#perform_inline' do
      it 'expect to perform' do
        expect(base_controller).to receive(:perform)
        base_controller.send(:perform_inline)
      end
    end

    describe '#perform_async' do
      let(:params) { double }
      let(:interchanger) { double }
      let(:interchanged_load_params) { double }
      let(:worker) { double }
      let(:topic) { rand.to_s }

      before do
        base_controller.interchanger = interchanger
        base_controller.worker = worker
        base_controller.topic = topic
      end

      it 'enqueue perform function' do
        base_controller.instance_variable_set :@params, params

        expect(base_controller.interchanger)
          .to receive(:load)
          .with(params)
          .and_return(interchanged_load_params)

        expect(worker)
          .to receive(:perform_async)
          .with(topic, interchanged_load_params)

        base_controller.send :perform_async
      end
    end

    context 'when we have a block based before_enqueue' do
      context 'and it throws abort to halt' do
        subject(:base_controller) do
          ClassBuilder.inherit(described_class) do
            before_enqueue do
              throw(:abort)
            end

            def perform
              self
            end
          end.new
        end

        it 'does not enqueue' do
          expect(base_controller).not_to receive(:enqueue)

          base_controller.schedule
        end
      end

      context 'and it does not throw abort to halt' do
        subject(:base_controller) do
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
          expect(base_controller).to receive(:perform_async)

          base_controller.schedule
        end
      end
    end

    context 'when we have a method based before_enqueue' do
      context 'and it throws abort to halt' do
        subject(:base_controller) do
          ClassBuilder.inherit(described_class) do
            before_enqueue :method

            def perform
              self
            end

            def method
              throw(:abort)
            end
          end.new
        end

        it 'does not enqueue' do
          expect(base_controller).not_to receive(:enqueue)

          base_controller.schedule
        end
      end

      context 'and it does not return false' do
        subject(:base_controller) do
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
          expect(base_controller).to receive(:perform_async)

          base_controller.schedule
        end
      end
    end
  end
end
