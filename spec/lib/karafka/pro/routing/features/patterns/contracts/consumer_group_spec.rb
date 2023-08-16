# frozen_string_literal: true

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) { { patterns: [] } }

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when patterns are not hashes' do
    before { config[:patterns] = [1, 2] }

    it { expect(check).not_to be_success }
  end

  context 'when there is no patterns key' do
    before { config.delete(:patterns) }

    it { expect(check).not_to be_success }
  end

  context 'when pattern is not valid' do
    before { config[:patterns] = [{}] }

    it { expect { check }.to raise_error(Karafka::Errors::InvalidConfigurationError) }
  end

  context 'when pattern is valid' do
    before { config[:patterns] = [{ name: /.*/, topic_name: 'xda' }] }

    it { expect(check).to be_success }
  end
end
