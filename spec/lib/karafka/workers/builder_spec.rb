require 'spec_helper'

RSpec.describe Karafka::Workers::Builder do
  subject { described_class.new(controller_class) }
  let(:controller_class) { double }

  describe '.new' do
    it 'should assign internally controller_class' do
      expect(subject.instance_variable_get('@controller_class')).to eq controller_class
    end
  end

  describe '#build' do
    context 'when the worker class already exists' do
      let(:name) { 'Karafka' }

      before do
        expect(subject)
          .to receive(:name)
          .and_return(name)
          .exactly(2).times
      end

      it 'should not build it again' do
        expect(subject.build).to eq Karafka
      end
    end

    context 'when a given worker does not exist' do
      context 'when the worker class does not exist' do
        context 'and it is on a root level' do
          let(:random) { rand(1000) }
          let(:name) { "Karafka#{random}Worker" }

          before do
            expect(subject)
              .to receive(:name)
              .and_return(name)
              .exactly(2).times
          end

          it 'should build it' do
            expect(subject.build.to_s).to eq "Karafka#{random}Worker"
          end
        end

        context 'and it is in a module/class' do
          let(:random) { rand(1000) }
          let(:name) { "Karafka#{random}Worker" }

          before do
            expect(subject)
              .to receive(:name)
              .and_return(name)
              .exactly(2).times

            expect(subject)
              .to receive(:scope)
              .and_return(Karafka)
          end

          it 'should build it in this scope' do
            expect(subject.build.to_s).to eq "Karafka::Karafka#{random}Worker"
          end
        end
      end
    end
  end

  describe '#name' do
    before do
      subject.instance_variable_set('@controller_class', controller_class)
    end

    context 'when this is a non namespaced typical controller_class' do
      let(:controller_class) { 'TypicalController' }

      it { expect(subject.send(:name)).to eq 'TypicalWorker' }
    end

    context 'when this is a non namespaced anonymous controller_class' do
      let(:controller_class) { "#<Class:#{object_id}>" }

      it { expect(subject.send(:name)).to eq "Class#{object_id}" }
    end

    context 'when this is a namespaced typical controller_class' do
      let(:controller_class) { 'Videos::TypicalController' }

      it { expect(subject.send(:name)).to eq 'TypicalWorker' }
    end

    context 'when this is a namespaced anonymous controller_class' do
      let(:controller_class) { "Videos::#<Class:#{object_id}>" }

      it { expect(subject.send(:name)).to eq "Class#{object_id}" }
    end
  end

  describe '#scope' do
    before do
      subject.instance_variable_set('@controller_class', controller_class)
    end

    context 'when this is a non namespaced typical controller_class' do
      let(:controller_class) { 'TypicalController' }

      it { expect(subject.send(:scope)).to eq Object }
    end

    context 'when this is a non namespaced anonymous controller_class' do
      let(:controller_class) { "#<Class:#{object_id}>" }

      it { expect(subject.send(:scope)).to eq Object }
    end

    context 'when this is a namespaced typical controller_class' do
      let(:controller_class) { 'Karafka::TypicalController' }

      it { expect(subject.send(:scope)).to eq Karafka }
    end

    context 'when this is a namespaced anonymous controller_class' do
      let(:controller_class) { "Karafka::#<Class:#{object_id}>" }

      it { expect(subject.send(:scope)).to eq Karafka }
    end
  end
end
