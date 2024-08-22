# frozen_string_literal: true

RSpec.describe_current do
  context 'when trying to define invalid schema' do
    it 'expect to fail' do
      expect do
        described_class.define do
          schedule(id: '#$%^&*(', cron: '* * * * *')
        end
      end.to raise_error(Karafka::Errors::InvalidConfigurationError)
    end
  end
end
