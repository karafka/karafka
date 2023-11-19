# frozen_string_literal: true

RSpec.describe_current do
  subject(:check) { described_class.new.call(pattern) }

  let(:pattern) { { regexp: /.*/, name: 'xda', regexp_string: '^xda' } }

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

  context 'when name is missing' do
    before { pattern.delete(:name) }

    it { expect(check).not_to be_success }
  end

  context 'when name is not a string' do
    before { pattern[:name] = 123 }

    it { expect(check).not_to be_success }
  end

  context 'when name is an invalid string' do
    before { pattern[:name] = '%^&*(' }

    it { expect(check).not_to be_success }
  end

  context 'when regexp string does not start with ^' do
    before { pattern[:regexp_string] = 'test' }

    it { expect(check).not_to be_success }
  end

  context 'when regexp string is only ^' do
    before { pattern[:regexp_string] = '^' }

    it { expect(check).not_to be_success }
  end

  context 'when regexp_string is missing' do
    before { pattern.delete(:regexp_string) }

    it { expect(check).not_to be_success }
  end
end
