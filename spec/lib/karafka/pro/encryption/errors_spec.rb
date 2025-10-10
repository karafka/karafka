# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  describe 'PrivateKeyNotFoundError' do
    subject(:error) { described_class::PrivateKeyNotFoundError }

    specify { expect(error).to be < Karafka::Errors::BaseError }
  end
end
