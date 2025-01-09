# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
