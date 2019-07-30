# frozen_string_literal: true

# Dummy module used for spec purposes
module TestModule
end

RSpec.describe Karafka::Helpers::ClassMatcher do
  subject(:matcher) { described_class.new(klass, from: from, to: to) }

  let(:from) { 'Base' }
  let(:to) { 'Matching' }
  let(:matching) { nil }

  let(:mod_klass) { stub_const('TestModule::Super2Base', Class.new) }
  let(:mod_matching) { stub_const('TestModule::Super2Matching', Class.new) }
  let(:mod_non_klass) { stub_const('TestModule::SuperNonBase', Class.new) }

  let(:root_klass) { stub_const('SuperBase', Class.new) }
  let(:root_matching) { stub_const('SuperMatching', Class.new) }
  let(:root_non_klass) { stub_const('SuperNonBase', Class.new) }

  before { matching }

  describe '#match' do
    context 'when a mathing class exists' do
      context 'when it without namespace' do
        let(:klass) { root_klass }
        let(:matching) { root_matching }

        it { expect(matcher.match).to eq matching }
      end

      context 'when it is with namespace' do
        let(:klass) { mod_klass }
        let(:matching) { mod_matching }

        it { expect(matcher.match).to eq matching }
      end
    end

    context 'when a matching class does not exist' do
      context 'when it without namespace' do
        let(:klass) { root_non_klass }

        it { expect(matcher.match).to eq nil }
      end

      context 'when it is with namespace' do
        let(:klass) { mod_non_klass }

        it { expect(matcher.match).to eq nil }
      end
    end

    context 'when klass is anonymous' do
      let(:klass) { Class.new }

      it { expect(matcher.match).to eq nil }
    end

    context 'when names match but not namespaces' do
      context 'when matching does not exist' do
        let(:klass) { stub_const('TestModule::SuperRandBase', Class.new) }
        let(:root_klass) { stub_const('SuperRandBase', Class.new) }
        let(:root_matching) { stub_const('SuperRandMatching', Class.new) }

        before do
          Object.send(:remove_const, :TestModule) if defined?(TestModule)
          klass
          root_klass
          root_matching
        end

        it { expect(matcher.match).to eq nil }
      end

      context 'when matching does exist' do
        let(:klass) { stub_const('TestModule::SuperRandBase', Class.new) }
        let(:matching) { stub_const('TestModule::SuperRandMatching', Class.new) }
        let(:root_klass) { stub_const('SuperRandBase', Class.new) }
        let(:root_matching) { stub_const('SuperRandMatching', Class.new) }

        before do
          klass
          root_klass
          matching
          root_matching
        end

        it { expect(matcher.match).to eq matching }
      end
    end
  end

  describe '#name' do
    context 'when it is without namespace' do
      let(:klass) { root_klass }

      it { expect(matcher.name).to eq root_matching.to_s }
    end

    context 'when it is with namespace' do
      let(:klass) { mod_klass }

      it { expect(matcher.name).to eq mod_matching.to_s.split('::').last }
    end

    context 'when klass is anonymous' do
      let(:klass) { Class.new }
      let(:expected_name) { klass.to_s.gsub(/[\#<>:]*/, '') + to }

      it { expect(matcher.name).to eq expected_name }
    end
  end

  describe '#scope' do
    context 'when it without namespace' do
      let(:klass) { root_klass }

      it { expect(matcher.scope).to eq ::Object }
    end

    context 'when it is with namespace' do
      let(:klass) { mod_klass }

      it { expect(matcher.scope).to eq TestModule }
    end
  end
end
