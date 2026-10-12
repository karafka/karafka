# frozen_string_literal: true

RSpec.describe Karafka::Admin::ConsumerGroups do
  subject(:admin_consumer_groups) { described_class }

  let(:name) { generate_topic_name }
  let(:name2) { generate_topic_name }

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
      before do
        Karafka::Admin::Topics.create(name, 1, 1)
        PRODUCERS.regular.produce_sync(topic: name, payload: "1")
      end

      let(:cgs_t) { { "doesnotexist" => [name] } }

      it { expect(results).to eq("doesnotexist" => { name => { 0 => { lag: -1, offset: -1 } } }) }
    end

    context "when running on an external client" do
      subject(:results) do
        described_class
          .new(external_client: external_client)
          .read_lags_with_offsets(cgs_t)
      end

      before do
        Karafka::Admin::Topics.create(name, 1, 1)
        PRODUCERS.regular.produce_sync(topic: name, payload: "1")
      end

      after { external_client.close }

      let(:external_client) do
        Rdkafka::Config.new(
          Karafka::App.config.kafka.merge("group.id": "doesnotexist")
        ).consumer
      end

      let(:cgs_t) { { "doesnotexist" => [name] } }

      it "expect to read via the external client and leave it open" do
        expect(results).to eq("doesnotexist" => { name => { 0 => { lag: -1, offset: -1 } } })
        expect(external_client.closed?).to be(false)
      end
    end
  end

  describe "#list" do
    subject(:listing) { described_class.list }

    let(:instance) { described_class.new }
    let(:allowed_states) do
      %i[unknown preparing_rebalance completing_rebalance stable dead empty]
    end

    before { allow(described_class).to receive(:new).and_return(instance) }

    context "when the broker responds normally" do
      before { allow(described_class).to receive(:new).and_call_original }

      it "returns an array of cooked entries" do
        expect(listing).to be_a(Array)

        listing.each do |entry|
          expect(entry[:group_id]).to be_a(String)
          expect(allowed_states).to include(entry[:state])
        end
      end
    end

    context "when normalizing the librdkafka numeric states" do
      let(:report) do
        instance_double(
          Rdkafka::Admin::ListConsumerGroupsReport,
          errors: [],
          groups: [
            {
              group_id: "g-stable",
              state: Rdkafka::Bindings::RD_KAFKA_CONSUMER_GROUP_STATE_STABLE
            },
            {
              group_id: "g-empty",
              state: Rdkafka::Bindings::RD_KAFKA_CONSUMER_GROUP_STATE_EMPTY
            },
            { group_id: "g-weird", state: 999 }
          ]
        )
      end

      before { allow(instance).to receive(:with_admin).and_return(report) }

      it "maps each numeric state to its cooked symbol and unknown codes to :unknown" do
        expect(listing).to eq(
          [
            { group_id: "g-stable", state: :stable },
            { group_id: "g-empty", state: :empty },
            { group_id: "g-weird", state: :unknown }
          ]
        )
      end
    end

    context "when the listing is partial with per-broker errors" do
      let(:error) { Rdkafka::RdkafkaError.new(-1) }
      let(:report) do
        instance_double(
          Rdkafka::Admin::ListConsumerGroupsReport,
          groups: [],
          errors: [error]
        )
      end

      before { allow(instance).to receive(:with_admin).and_return(report) }

      it "surfaces the first per-broker error instead of returning a partial listing" do
        expect { listing }.to raise_error(error)
      end
    end
  end

  describe "#describe" do
    subject(:description) { described_class.describe(group_id) }

    let(:group_id) { SecureRandom.uuid }

    context "when the consumer group does not exist" do
      it "reports it as dead with no members" do
        expect(description[:group_id]).to eq(group_id)
        expect(description[:state]).to eq(:dead)
        expect(description[:members]).to eq([])
      end
    end
  end

  describe "#describe_many" do
    subject(:descriptions) { described_class.describe_many(group_ids) }

    let(:group_ids) { [group_id] }
    let(:group_id) { SecureRandom.uuid }
    let(:instance) { described_class.new }
    let(:admin) { instance_double(Rdkafka::Admin) }
    let(:coordinator) { { id: 1, host: "127.0.0.1", port: 9092, rack: nil } }
    # 16 is the Kafka NOT_COORDINATOR error code
    let(:not_ready_error) { Rdkafka::RdkafkaError.new(16) }

    def group_report(*groups)
      report = instance_double(Rdkafka::Admin::DescribeConsumerGroupsReport, groups: groups)
      instance_double(Rdkafka::Admin::DescribeConsumerGroupsHandle, wait: report)
    end

    def described_group(id, state: Rdkafka::Bindings::RD_KAFKA_CONSUMER_GROUP_STATE_DEAD)
      {
        group_id: id,
        error: nil,
        is_simple_consumer_group: false,
        state: state,
        state_name: "Dead",
        type: Rdkafka::Bindings::RD_KAFKA_CONSUMER_GROUP_TYPE_CLASSIC,
        type_name: "Classic",
        partition_assignor: "range",
        coordinator: coordinator,
        authorized_operations: nil,
        members: []
      }
    end

    before do
      allow(described_class).to receive(:new).and_return(instance)
      allow(instance).to receive(:with_admin).and_yield(admin)
    end

    context "when no consumer groups are requested" do
      let(:group_ids) { [] }

      it { expect(descriptions).to eq([]) }
    end

    context "when the consumer groups do not exist" do
      let(:group_ids) { [SecureRandom.uuid, SecureRandom.uuid] }

      before { allow(described_class).to receive(:new).and_call_original }

      it "reports each of them as dead with no members, in the requested order" do
        expect(descriptions.map { |group| group[:group_id] }).to eq(group_ids)
        expect(descriptions.map { |group| group[:state] }).to eq(%i[dead dead])
        expect(descriptions.map { |group| group[:members] }).to eq([[], []])
      end
    end

    context "when cooking the librdkafka consumer group description" do
      let(:group) do
        described_group(group_id, state: Rdkafka::Bindings::RD_KAFKA_CONSUMER_GROUP_STATE_STABLE)
          .merge(
            members: [
              {
                member_id: "m1",
                client_id: "c1",
                group_instance_id: nil,
                host: "/127.0.0.1",
                assignment: { "t1" => [0, 1] },
                target_assignment: nil
              }
            ]
          )
      end

      before { allow(admin).to receive(:describe_consumer_groups).and_return(group_report(group)) }

      it "returns the cooked consumer group with a symbol state and plain members" do
        expect(descriptions).to eq(
          [
            {
              group_id: group_id,
              state: :stable,
              partition_assignor: "range",
              coordinator: coordinator,
              members: [
                {
                  member_id: "m1",
                  client_id: "c1",
                  group_instance_id: nil,
                  host: "/127.0.0.1",
                  assignment: { "t1" => [0, 1] }
                }
              ]
            }
          ]
        )
      end
    end

    context "when the broker returns the consumer groups in a different order" do
      let(:group_ids) { %w[g1 g2] }

      before do
        allow(admin)
          .to receive(:describe_consumer_groups)
          .and_return(group_report(described_group("g2"), described_group("g1")))
      end

      it "returns them in the requested order" do
        expect(descriptions.map { |group| group[:group_id] }).to eq(%w[g1 g2])
      end
    end

    context "when a consumer group could not be described" do
      let(:error) { Rdkafka::RdkafkaError.new(-1) }

      before do
        allow(admin)
          .to receive(:describe_consumer_groups)
          .and_return(group_report({ group_id: group_id, error: error }))
      end

      it "raises the consumer group error without retrying" do
        expect { descriptions }.to raise_error(error)
        expect(admin).to have_received(:describe_consumer_groups).once
      end
    end

    context "when a coordinator is not ready yet and then becomes ready" do
      let(:group_ids) { %w[g1 g2] }

      before do
        allow(admin)
          .to receive(:describe_consumer_groups)
          .and_return(
            group_report(described_group("g1"), { group_id: "g2", error: not_ready_error }),
            group_report({ group_id: "g2", error: not_ready_error }),
            group_report(described_group("g2"))
          )
      end

      it "retries only the not ready consumer groups within one admin client" do
        expect(descriptions.map { |group| group[:group_id] }).to eq(%w[g1 g2])
        expect(admin).to have_received(:describe_consumer_groups).with(%w[g1 g2]).once
        expect(admin).to have_received(:describe_consumer_groups).with(%w[g2]).twice
        expect(instance).to have_received(:with_admin).once
      end
    end

    context "when a coordinator does not become ready in time" do
      before do
        allow(admin)
          .to receive(:describe_consumer_groups)
          .and_return(group_report({ group_id: group_id, error: not_ready_error }))
        allow(described_class).to receive(:max_retries_duration).and_return(0)
      end

      it "raises the coordinator error" do
        expect { descriptions }.to raise_error(not_ready_error)
      end
    end
  end

  describe "#trigger_rebalance" do
    subject(:trigger) { described_class.trigger_rebalance(group_id) }

    let(:group_id) { SecureRandom.uuid }

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
