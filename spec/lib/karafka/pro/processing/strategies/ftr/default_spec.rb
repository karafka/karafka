# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  it { expect(described_class::FEATURES).to eq(%i[filtering]) }
end
