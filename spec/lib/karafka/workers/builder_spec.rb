require 'spec_helper'

RSpec.describe Karafka::Workers::Builder do
  subject(:builder) { described_class.new(controller_class) }
  let(:controller_class) { double }

  describe '.new' do
    it 'assigns internally controller_class' do
      expect(builder.instance_variable_get('@controller_class')).to eq controller_class
    end
  end

  describe '#build' do
    let(:base) { Karafka::BaseWorker }

    before do
      allow(builder)
        .to receive(:base)
        .and_return(base)
    end

    context 'when the worker class already exists' do
      let(:name) { 'Karafka' }

      before do
        expect(builder)
          .to receive(:name)
          .and_return(name)
          .exactly(2).times
      end

      it 'does not build it again' do
        expect(builder.build).to eq Karafka
      end
    end

    context 'when a given worker does not exist' do
      context 'when the worker class does not exist' do
        context 'and it is on a root level' do
          let(:random) { rand(1000) }
          let(:name) { "Karafka#{random}Worker" }

          before do
            expect(builder)
              .to receive(:name)
              .and_return(name)
              .exactly(2).times
          end

          it 'builds it' do
            expect(builder.build.to_s).to eq "Karafka#{random}Worker"
          end
        end

        context 'and it is in a module/class' do
          let(:random) { rand(1000) }
          let(:name) { "Karafka#{random}Worker" }

          before do
            expect(builder)
              .to receive(:name)
              .and_return(name)
              .exactly(2).times

            expect(builder)
              .to receive(:scope)
              .and_return(Karafka)
          end

          it 'builds it in this scope' do
            expect(builder.build.to_s).to eq "Karafka::Karafka#{random}Worker"
          end
        end
      end
    end
  end

  describe '#name' do
    before do
      builder.instance_variable_set('@controller_class', controller_class)
    end

    context 'when this is a non namespaced typical controller_class' do
      let(:controller_class) { 'TypicalController' }

      it { expect(builder.send(:name)).to eq 'TypicalWorker' }
    end

    context 'when this is a non namespaced anonymous controller_class' do
      let(:controller_class) { "#<Class:#{object_id}>" }

      it { expect(builder.send(:name)).to eq "Class#{object_id}" }
    end

    context 'when this is a namespaced typical controller_class' do
      let(:controller_class) { 'Videos::TypicalController' }

      it { expect(builder.send(:name)).to eq 'TypicalWorker' }
    end

    context 'when this is a namespaced anonymous controller_class' do
      let(:controller_class) { "Videos::#<Class:#{object_id}>" }

      it { expect(builder.send(:name)).to eq "Class#{object_id}" }
    end
  end

  describe '#scope' do
    before do
      builder.instance_variable_set('@controller_class', controller_class)
    end

    context 'when this is a non namespaced typical controller_class' do
      let(:controller_class) { 'TypicalController' }

      it { expect(builder.send(:scope)).to eq Object }
    end

    context 'when this is a non namespaced anonymous controller_class' do
      let(:controller_class) { "#<Class:#{object_id}>" }

      it { expect(builder.send(:scope)).to eq Object }
    end

    context 'when this is a namespaced typical controller_class' do
      let(:controller_class) { 'Karafka::TypicalController' }

      it { expect(builder.send(:scope)).to eq Karafka }
    end

    context 'when this is a namespaced anonymous controller_class' do
      let(:controller_class) { "Karafka::#<Class:#{object_id}>" }

      it { expect(builder.send(:scope)).to eq Karafka }
    end
  end

  describe '#base' do
    before do
      expect(Karafka::BaseWorker)
        .to receive(:subclasses)
        .and_return([descendant])
    end

    context 'when there is a direct descendant of Karafka::BaseWorker' do
      let(:descendant) { double }

      it 'expect to use it' do
        expect(builder.send(:base)).to eq descendant
      end
    end

    context 'when there is no direct descendant of Karafka::BaseWorker' do
      let(:descendant) { nil }
      let(:error) { Karafka::Errors::BaseWorkerDescentantMissing }

      it { expect { builder.send(:base) }.to raise_error(error) }
    end
  end
end
