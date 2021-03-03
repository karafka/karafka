# frozen_string_literal: true

RSpec.describe_current do
  subject(:karafka_env) { described_class.new }

  describe '#initialize' do
    context 'when we dont have any ENVs that we can use' do
      before { allow(ENV).to receive(:[]).and_return(nil) }

      it 'expect to use default' do
        expect(karafka_env).to eq 'development'
      end
    end
  end

  describe '#respond_to? with missing' do
    context 'when we check for regular existing methods' do
      %w[
        chop
        upcase!
      ].each do |method_name|
        it 'expect not to respond to those' do
          expect(karafka_env.respond_to?(method_name)).to eq true
        end
      end
    end

    context 'when we check for regular named non-existing methods' do
      %w[
        supermethod
        extra_other
      ].each do |method_name|
        it 'expect not to respond to those' do
          expect(karafka_env.respond_to?(method_name)).to eq false
        end
      end
    end

    context 'when we check for questionmark environmentable methods' do
      %w[
        test?
        production?
        development?
        unknown?
      ].each do |method_name|
        it 'expect not to respond to those' do
          expect(karafka_env.respond_to?(method_name)).to eq true
        end
      end
    end
  end

  %w[
    production test development
  ].each do |env|
    context "environment: #{env}" do
      before { karafka_env.replace(env) }

      it { expect(karafka_env.public_send(:"#{env}?")).to eq true }
    end
  end

  %w[
    unknown
    unset
    invalid
  ].each do |env|
    context "environment: #{env}" do
      it { expect(karafka_env.public_send(:"#{env}?")).to eq false }
    end
  end
end
