# frozen_string_literal: true

# Dummy module used for spec purposes
module TestModule
end

RSpec.describe Karafka::Helpers::ClassMatcher do
  subject(:matcher) { described_class.new(klass, from: from, to: to) }

  let(:from) { 'Base' }
  let(:to) { 'Matching' }
  let(:matching) { nil }

  let(:mod_klass) do
    module TestModule
      class Super2Base
        self
      end
    end
  end

  let(:mod_matching) do
    module TestModule
      class Super2Matching
        self
      end
    end
  end

  let(:mod_non_klass) do
    module TestModule
      class SuperNonBase
        self
      end
    end
  end

  let(:root_klass) { class SuperBase; self end }
  let(:root_matching) { class SuperMatching; self end }
  let(:root_non_klass) { class SuperNonBase; self end }

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
      context 'and matching does not exist' do
        let(:klass) do
          module TestModule
            class SuperRandBase
              self
            end
          end
        end

        let(:root_klass) { class SuperRandBase; self end }
        let(:root_matching) { class SuperRandMatching; self end }

        before do
          klass
          root_klass
          root_matching
        end

        it { expect(matcher.match).to eq nil }
      end

      context 'and matching does exist' do
        let(:klass) do
          module TestModule
            class SuperRandBase
              self
            end
          end
        end

        let(:matching) do
          module TestModule
            class SuperRandMatching
              self
            end
          end
        end

        let(:root_klass) { class SuperRandBase; self end }
        let(:root_matching) { class SuperRandMatching; self end }

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
      let(:expected_name) { klass.to_s.gsub(described_class::CONSTANT_REGEXP, '') }

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
