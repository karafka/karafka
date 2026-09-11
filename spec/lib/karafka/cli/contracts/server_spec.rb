# frozen_string_literal: true

RSpec.describe_current do
  subject(:contract) { described_class.new }

  let(:subscription_groups) { { 1 => 1 } }
  let(:config) do
    {
      include_consumer_groups: [],
      include_share_groups: [],
      include_subscription_groups: [],
      include_topics: [],
      exclude_consumer_groups: [],
      exclude_share_groups: [],
      exclude_subscription_groups: [],
      exclude_topics: []
    }
  end

  before { allow(Karafka::App).to receive(:subscription_groups).and_return(subscription_groups) }

  context "when config is valid" do
    it { expect(contract.call(config)).to be_success }
  end

  context "when we want to use share groups that are not defined" do
    before { config[:include_share_groups] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when we want to exclude share groups that are not defined" do
    before { config[:exclude_share_groups] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when we want to use a share groups wildcard pattern that matches nothing yet" do
    before { config[:include_share_groups] = ["#{rand}-*"] }

    it { expect(contract.call(config)).to be_success }
  end

  context "when we reference a defined share group in the exclusions" do
    before do
      config[:exclude_share_groups] = ["present-sg"]

      share_group = instance_double(
        Karafka::Routing::ShareGroups::Group,
        name: "present-sg",
        share_group?: true,
        consumer_group?: false
      )

      routes = [share_group]
      allow(routes).to receive_messages(consumer_groups: [], share_groups: [share_group])
      allow(Karafka::App).to receive(:routes).and_return(routes)
    end

    it { expect(contract.call(config)).to be_success }
  end

  context "when a share group name is used in the consumer groups filter" do
    before do
      config[:include_consumer_groups] = ["present-sg"]

      share_group = instance_double(
        Karafka::Routing::ShareGroups::Group,
        name: "present-sg",
        share_group?: true,
        consumer_group?: false
      )

      routes = [share_group]
      allow(routes).to receive_messages(consumer_groups: [], share_groups: [share_group])
      allow(Karafka::App).to receive(:routes).and_return(routes)
    end

    it "expect not to accept a share group name as a consumer group" do
      expect(contract.call(config)).not_to be_success
    end
  end

  context "when we want to use consumer groups that are not defined" do
    before { config[:include_consumer_groups] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when we want to use a consumer groups wildcard pattern that matches nothing yet" do
    before { config[:include_consumer_groups] = ["#{rand}-*"] }

    it { expect(contract.call(config)).to be_success }
  end

  context "when we want to exclude consumer groups that are not defined" do
    before { config[:exclude_consumer_groups] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when we want to exclude a consumer groups wildcard pattern that matches nothing yet" do
    before { config[:exclude_consumer_groups] = ["#{rand}-*"] }

    it { expect(contract.call(config)).to be_success }
  end

  context "when we want to use topics that are not defined" do
    before { config[:include_topics] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when we want to use a topics wildcard pattern that matches nothing yet" do
    before { config[:include_topics] = ["#{rand}-*"] }

    it { expect(contract.call(config)).to be_success }
  end

  context "when we want to exclude topics that are not defined" do
    before { config[:exclude_topics] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when we want to exclude a topics wildcard pattern that matches nothing yet" do
    before { config[:exclude_topics] = ["#{rand}-*"] }

    it { expect(contract.call(config)).to be_success }
  end

  context "when we want to use subscription groups that are not defined" do
    before { config[:include_subscription_groups] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when we want to use a subscription groups wildcard pattern that matches nothing yet" do
    before { config[:include_subscription_groups] = ["#{rand}-*"] }

    it { expect(contract.call(config)).to be_success }
  end

  context "when we want to exclude subscription groups that are not defined" do
    before { config[:exclude_subscription_groups] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when we want to exclude a subscription groups wildcard pattern matching nothing yet" do
    before { config[:exclude_subscription_groups] = ["#{rand}-*"] }

    it { expect(contract.call(config)).to be_success }
  end

  context "when nothing to listen on" do
    let(:subscription_groups) { {} }

    it { expect(contract.call(config)).not_to be_success }
  end
end
