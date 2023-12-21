# frozen_string_literal: true

RSpec.describe_current do
  subject(:cg) { build(:routing_consumer_group) }

  let(:adding_pattern) do
    cg.public_send(:subscription_group=, :name, multiplex: multiplex) do
      topic :test do
        consumer Class.new
      end
    end
  end

  it { expect(cg.subscription_groups).to be_empty }

  context 'when adding regular subscription group' do
    let(:multiplex) { 1 }

    before { adding_pattern }

    it { expect(cg.subscription_groups.size).to eq(1) }
  end

  context 'when adding multiplexed subscription group' do
    let(:multiplex) { 5 }

    before { adding_pattern }

    it { expect(cg.subscription_groups.size).to eq(5) }
  end
end
