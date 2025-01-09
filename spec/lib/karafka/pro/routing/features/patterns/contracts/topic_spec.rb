# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:check) { described_class.new.call(topic) }

  subject(:contract) { described_class.new }

  context 'when patterns configuration is valid' do
    let(:topic) do
      {
        patterns: {
          active: true,
          type: :matcher
        }
      }
    end

    it { expect(check).to be_success }
  end

  context 'when patterns active attribute is not valid' do
    let(:topic) do
      {
        patterns: {
          active: nil,
          type: :matcher
        }
      }
    end

    it { expect(check).not_to be_success }
  end

  context 'when patterns type attribute is not valid' do
    let(:topic) do
      {
        patterns: {
          active: true,
          type: :invalid_type
        }
      }
    end

    it { expect(check).not_to be_success }
  end
end
