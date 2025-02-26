# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:base) { described_class.new }

  it { expect { base.apply!([]) }.to raise_error(NotImplementedError) }
  it { expect(base.action).to eq(:skip) }
  it { expect(base.timeout).to eq(nil) }
  it { expect(base.cursor).to be_nil }
  it { expect(base.mark_as_consumed?).to be(false) }
  it { expect(base.marking_method).to eq(:mark_as_consumed) }
end
