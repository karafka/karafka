require 'spec_helper'

RSpec.describe Karafka::BaseController do
  let(:working_class) do
    ClassBuilder.inherit(described_class) do
      self.group = rand
      self.topic = rand

      def perform
        self
      end
    end
  end

  subject { ClassBuilder.inherit(described_class) }

  context 'class methods and behaviours' do
    describe '#group' do
      before do
        subject.instance_variable_set(:'@group', group)
      end

      context 'when group value is set' do
        let(:group) { rand.to_s }

        it { expect(subject.group).to eq group }
      end

      context 'when group value is not set' do
        let(:group) { nil }

        it 'should build it based on the app name and current controller topic' do
          expect(subject.group).to eq "#{Karafka::App.config.name}_#{subject.topic}"
        end
      end
    end

    describe '#topic' do
      before do
        subject.instance_variable_set(:'@topic', topic)
      end

      context 'when topic value is set' do
        let(:topic) { rand.to_s }

        it { expect(subject.topic).to eq topic }
      end

      context 'when topic value is not set' do
        context 'and it is not namespaced controller' do
          let(:topic) { nil }

          it 'should build it based on the controller name' do
            expect(subject.topic).to eq subject.to_s.underscore.sub('_controller', '').tr('/', '_')
          end
        end

        context 'and it is namespaced controller' do
          subject do
            # Dummy spec module
            module DummyModule
              # Dummy spec controller in a module
              class Ctrl < Karafka::BaseController
                self
              end
            end
          end

          let(:topic) { nil }

          it 'should build it based on the controller name and the namespace' do
            expect(subject.topic).to eq subject.to_s.underscore.sub('_controller', '').tr('/', '_')
          end
        end
      end
    end

    describe '#parser' do
      before do
        working_class.parser = parser
      end

      context 'when parser is already assigned' do
        let(:parser) { double }

        it { expect(working_class.parser).to eq parser }
      end

      context 'when parser is not assigned' do
        let(:parser) { nil }

        it { expect(working_class.parser).to eq JSON }
      end
    end

    describe '#worker' do
      before do
        working_class.worker = worker
      end

      context 'when worker is already assigned' do
        let(:worker) { double }

        before do
          expect(Karafka::Workers::Builder)
            .not_to receive(:new)
        end

        it 'should not try to build a new one and return currently assigned' do
          expect(working_class.worker).to eq worker
        end
      end

      context 'when worker is not assigned' do
        let(:worker) { nil }
        let(:built_worker) { double }
        let(:builder) { double }

        before do
          expect(Karafka::Workers::Builder)
            .to receive(:new)
            .with(working_class)
            .and_return(builder)

          expect(builder)
            .to receive(:build)
            .and_return(built_worker)

          working_class.worker = worker
        end

        it 'should build a new one and return it' do
          expect(working_class.worker).to eq built_worker
        end
      end
    end

    describe '#interchanger' do
      before do
        subject.instance_variable_set(:'@interchanger', interchanger)
      end

      context 'when interchanger is set' do
        let(:interchanger) { rand.to_s }

        it { expect(subject.interchanger).to eq interchanger }
      end

      context 'when interchanger is not set' do
        let(:interchanger) { nil }

        it 'should use a default interchanger' do
          expect(subject.interchanger).to eq Karafka::Params::Interchanger
        end
      end
    end
  end

  context 'instance methods and behaviours' do
    subject { working_class.new }

    describe 'initial exceptions' do
      context 'when perform method is not defined' do
        context 'but we use custom worker' do
          subject do
            ClassBuilder.inherit(described_class) do
              self.group = rand
              self.topic = rand
              self.worker = Class.new
            end
          end

          it 'expect not to raise an exception' do
            expect { subject.new }.not_to raise_error
          end
        end

        context 'and we use worker built by default' do
          subject do
            ClassBuilder.inherit(described_class) do
              self.group = rand
              self.topic = rand
            end
          end

          it 'should raise an exception' do
            expect { subject.new }.to raise_error(Karafka::Errors::PerformMethodNotDefined)
          end
        end
      end

      context 'when all options are defined' do
        subject do
          ClassBuilder.inherit(described_class) do
            self.group = rand
            self.topic = rand

            def perform
              self
            end
          end
        end

        it 'should not raise an exception' do
          expect { subject.new }.not_to raise_error
        end
      end
    end

    describe '#schedule' do
      context 'when there are no callbacks' do
        it 'should just schedule via perform_async' do
          expect(subject).to receive(:perform_async)

          subject.schedule
        end
      end
    end

    describe '#params=' do
      let(:message) { double }
      let(:params) { double }

      it 'should create params instance and assign it' do
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

      it 'should retrieve params data' do
        expect(params)
          .to receive(:retrieve)
          .and_return(params)

        expect(subject.send(:params)).to eq params
      end
    end

    describe '#perform_async' do
      context 'when we want to perform async stuff' do
        let(:params) { double }
        let(:interchanged_load_params) { double }

        it 'enqueue perform function' do
          subject.instance_variable_set :@params, params

          expect(subject.class.interchanger)
            .to receive(:load)
            .with(params)
            .and_return(interchanged_load_params)

          expect(Karafka::Workers::BaseWorker)
            .to receive(:perform_async)
            .with(subject.class, interchanged_load_params)

          subject.send :perform_async
        end
      end
    end

    context 'when we have a block based before_enqueue' do
      context 'and it returns false' do
        subject do
          ClassBuilder.inherit(described_class) do
            self.group = rand
            self.topic = rand

            before_enqueue do
              false
            end

            def perform
              self
            end
          end.new
        end

        it 'should not enqueue' do
          expect(subject).not_to receive(:enqueue)

          subject.schedule
        end
      end

      context 'and it does not return false' do
        subject do
          ClassBuilder.inherit(described_class) do
            self.group = rand
            self.topic = rand

            before_enqueue do
              true
            end

            def perform
              self
            end
          end.new
        end

        let(:params) { double }

        it 'should execute perform_async' do
          expect(subject).to receive(:perform_async)

          subject.schedule
        end
      end
    end

    context 'when we have a method based before_enqueue' do
      context 'and it returns false' do
        subject do
          ClassBuilder.inherit(described_class) do
            self.group = rand
            self.topic = rand

            before_enqueue :method

            def perform
              self
            end

            def method
              false
            end
          end.new
        end

        it 'should not enqueue' do
          expect(subject).not_to receive(:enqueue)

          subject.schedule
        end
      end

      context 'and it does not return false' do
        subject do
          ClassBuilder.inherit(described_class) do
            self.group = rand
            self.topic = rand

            before_enqueue :method

            def perform
              self
            end

            def method
              true
            end
          end.new
        end

        it 'should enqueue with perform_async' do
          expect(subject).to receive(:perform_async)

          subject.schedule
        end
      end
    end
  end
end
