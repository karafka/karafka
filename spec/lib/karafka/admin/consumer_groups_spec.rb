# frozen_string_literal: true

RSpec.describe Karafka::Admin::ConsumerGroups do
  subject(:admin_consumer_groups) { described_class }

  let(:name) { "it-#{SecureRandom.uuid}" }
  let(:name2) { "it-#{SecureRandom.uuid}" }

  describe "#seek" do
    subject(:seeking) { described_class.seek(cg_id, map) }

    let(:cg_id) { SecureRandom.uuid }
    let(:topic) { name }
    let(:partition) { 0 }
    let(:offset) { 0 }
    let(:map) { { topic => { partition => offset } } }

    before { Karafka::Admin::Topics.create(topic, 1, 1) }

    context "when given consumer group does not exist" do
      it "expect not to throw error and operate" do
        expect { seeking }.not_to raise_error
      end
    end

    context "when using the topic level map" do
      let(:map) { { topic => offset } }

      it "expect not to throw error and operate" do
        expect { seeking }.not_to raise_error
      end
    end

    context "when using the topic level map with time reference on empty topic" do
      let(:offset) { Time.now - 60 }
      let(:map) { { topic => offset } }

      it "expect not to throw error and operate" do
        expect { seeking }.not_to raise_error
      end
    end
  end

  describe "#copy" do
    subject(:copy) { described_class.copy(previous_name, new_name, topics) }

    let(:previous_name) { rand.to_s }
    let(:new_name) { rand.to_s }
    let(:topics) { [rand.to_s] }

    context "when old name does not exist" do
      it "expect not to raise error because it will not have offsets for old cg" do
        expect(copy).to be(false)
      end
    end

    context "when old name exists but no topics to migrate are given" do
      let(:topics) { [] }

      it { expect { copy }.not_to raise_error }
      it { expect(copy).to be(false) }
    end

    context "when requested topics do not exist but CG does" do
      before do
        Karafka::Admin::Topics.create(name, 1, 1)
        described_class.seek(previous_name, name => { 0 => 10 })
      end

      it { expect { copy }.not_to raise_error }
      it { expect(copy).to be(false) }
    end
  end

  describe "#rename" do
    subject(:rename) { described_class.rename(previous_name, new_name, topics) }

    let(:previous_name) { rand.to_s }
    let(:new_name) { rand.to_s }
    let(:topics) { [rand.to_s] }

    context "when old name does not exist" do
      it { expect(rename).to be(false) }
    end

    context "when old name exists but no topics to migrate are given" do
      let(:topics) { [] }

      it { expect { rename }.not_to raise_error }
    end

    context "when requested topics do not exist but CG does" do
      before do
        Karafka::Admin::Topics.create(name, 1, 1)
        described_class.seek(previous_name, name => { 0 => 10 })
      end

      it { expect { rename }.not_to raise_error }
      it { expect(rename).to be(false) }
    end
  end

  describe "#delete" do
    subject(:deletion) { described_class.delete(cg_id) }

    context "when requested consumer group does not exist" do
      let(:cg_id) { SecureRandom.uuid }

      it do
        expect { deletion }.to raise_error(Rdkafka::RdkafkaError)
      end
    end

    # The case where given consumer group exists we check in the integrations, because it is
    # much easier to test with integrations on created consumer group
  end

  describe "#read_lags_with_offsets" do
    subject(:results) { described_class.read_lags_with_offsets(cgs_t) }

    context "when we query for a non-existent topic with a non-existing CG" do
      let(:cgs_t) { { "doesnotexist" => ["doesnotexisttopic"] } }

      it { expect(results).to eq("doesnotexist" => { "doesnotexisttopic" => {} }) }
    end

    context "when querying existing topic with a CG that never consumed it" do
      before { PRODUCERS.regular.produce_sync(topic: name, payload: "1") }

      let(:cgs_t) { { "doesnotexist" => [name] } }

      it { expect(results).to eq("doesnotexist" => { name => { 0 => { lag: -1, offset: -1 } } }) }
    end
  end

  describe "#trigger_rebalance" do
    subject(:trigger) { described_class.trigger_rebalance(consumer_group_id) }

    let(:consumer_group_id) { SecureRandom.uuid }

    context "when consumer group is not in routing" do
      it "expect to raise InvalidConfigurationError with proper message" do
        expect { trigger }.to raise_error(
          Karafka::Errors::InvalidConfigurationError,
          /not found in routing/
        )
      end
    end

    # Successful case is tested in integration specs since it requires proper routing setup
  end
end
