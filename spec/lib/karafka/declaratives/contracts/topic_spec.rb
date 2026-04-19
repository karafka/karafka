# frozen_string_literal: true

RSpec.describe Karafka::Declaratives::Contracts::Topic do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      declaratives: {
        active: true,
        partitions: 1,
        replication_factor: 2,
        details: {}
      }
    }
  end

  context "when config is valid" do
    it { expect(check).to be_success }
  end

  context "when active flag is false" do
    before { config[:declaratives][:active] = false }

    it { expect(check).to be_success }
  end

  context "when there are not enough partitions" do
    before { config[:declaratives][:partitions] = 0 }

    it { expect(check).not_to be_success }
  end

  context "when replication_factor is not positive" do
    before { config[:declaratives][:replication_factor] = 0 }

    it { expect(check).not_to be_success }
  end

  context "when details are not a hash" do
    before { config[:declaratives][:details] = 0 }

    it { expect(check).not_to be_success }
  end

  context "when details are a hash with non-symbol keys" do
    before { config[:declaratives][:details] = { "test" => 1 } }

    it { expect(check).not_to be_success }
  end
end
