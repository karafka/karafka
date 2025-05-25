# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  let(:config) do
    instance_double(
      Karafka::Pro::Routing::Features::VirtualPartitions::Config
    )
  end

  subject(:distributor) { described_class.new(config) }

  describe '#initialize' do
    it 'expect to store config' do
      expect(distributor.send(:config)).to eq(config)
    end
  end
end
