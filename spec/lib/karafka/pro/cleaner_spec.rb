# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Availability of this feature mostly tested in the integration suite

RSpec.describe_current do
  subject(:cleaner) { described_class }

  describe '#post_setup' do
    it { expect { cleaner }.not_to raise_error }
  end
end
