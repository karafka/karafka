# frozen_string_literal: true

RSpec.describe_current do
  subject(:check) { described_class.new.call(pattern) }

  let(:pattern) { { regexp: /.*/, topic_regexp: 'xda' } }

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when regexp is not a regexp' do
    before { pattern[:regexp] = 'na' }

    it { expect(check).not_to be_success }
  end

  context 'when regexp is missing' do
    before { pattern.delete(:regexp) }

    it { expect(check).not_to be_success }
  end

  context 'when regexp is not a Regexp' do
    before { pattern[:regexp] = 'not_a_regexp' }

    it { expect(check).not_to be_success }
  end

  context 'when topic_regexp is missing' do
    before { pattern.delete(:topic_regexp) }

    it { expect(check).not_to be_success }
  end

  context 'when topic_regexp is not a string' do
    before { pattern[:topic_regexp] = 123 }

    it { expect(check).not_to be_success }
  end

  context 'when topic_regexp is an invalid string' do
    before { pattern[:topic_regexp] = '%^&*(' }

    it { expect(check).not_to be_success }
  end
end
