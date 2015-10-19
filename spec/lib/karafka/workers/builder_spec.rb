require 'spec_helper'

RSpec.describe Karafka::Workers::Builder do
  subject { described_class.new(controller) }
  let(:controller) { double }

  describe '.new' do
    it 'should assign internally controller' do
      expect(subject.instance_variable_get('@controller')).to eq controller
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
    end
  end

  describe '#name' do
    before do
      subject.instance_variable_set('@controller', controller)
    end

    context 'when this is a non namespaced typical controller' do
      let(:controller) { 'TypicalController' }

      it { expect(subject.send(:name)).to eq 'TypicalWorker' }
    end

    context 'when this is a non namespaced anonymous controller' do
      let(:controller) { "#<Class:#{object_id}>" }

      it { expect(subject.send(:name)).to eq "Class#{object_id}" }
    end

    context 'when this is a namespaced typical controller' do
      let(:controller) { 'Namespaced::TypicalController' }

      it { expect(subject.send(:name)).to eq 'Namespaced::TypicalWorker' }
    end

    context 'when this is a namespaced anonymous controller' do
      let(:controller) { "Namespaced::#<Class:#{object_id}>" }

      it { expect(subject.send(:name)).to eq "Namespaced::Class#{object_id}" }
    end
  end
end
