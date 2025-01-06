# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) { described_class.new(name, consumer_group) }

  let(:consumer_group) { instance_double(Karafka::Routing::ConsumerGroup, id: group_id) }
  let(:name) { 'test' }
  let(:group_id) { rand.to_s }
  let(:consumer) { Class.new(Karafka::BaseConsumer) }

  before { topic.consumer = consumer }

  describe '#name' do
    it 'expect to return stringified topic' do
      expect(topic.name).to eq name.to_s
    end
  end

  describe '#consumer_group' do
    it { expect(topic.consumer_group).to eq consumer_group }
  end

  describe '#id' do
    it { expect(topic.id).to eq "#{consumer_group.id}_#{name}" }
  end

  describe '#consumer_class' do
    # This is just an alias
    it { expect(topic.consumer).to eq(topic.consumer_class) }
  end

  describe '#consumer' do
    context 'when persistence is turned on' do
      it { expect(topic.consumer).to eq(topic.consumer_class) }
    end

    context 'when persistence is off' do
      before { topic.consumer_persistence = false }

      it { expect(topic.consumer).to eq(topic.consumer_class) }

      context 'when given class cannot be found' do
        before { topic.consumer = 'Na' }

        it 'expect to return the consumer as it is expected to be an anonymous class' do
          expect(topic.consumer).to eq(topic.consumer_class)
        end
      end
    end
  end

  %w[kafka manual_offset_management max_messages max_wait_time].each do |attribute|
    it { expect(topic).to respond_to(attribute) }
  end

  describe '#active?' do
    context 'when there are no topics in the topics' do
      it { expect(topic.active?).to be(true) }
    end

    context 'when our topic name is in server topics' do
      before do
        Karafka::App
          .config
          .internal
          .routing
          .activity_manager
          .include(:topics, name)
      end

      it { expect(topic.active?).to be(true) }
    end

    context 'when our topic name is not in server topics' do
      before do
        Karafka::App
          .config
          .internal
          .routing
          .activity_manager
          .include(:topics, 'na')
      end

      it { expect(topic.active?).to be(false) }
    end

    context 'when we set the topic to active via #active' do
      before { topic.active(true) }

      it { expect(topic.active?).to be(true) }
    end

    context 'when we set the topic to inactive via #active' do
      before { topic.active(false) }

      it { expect(topic.active?).to be(false) }
    end
  end

  describe '#to_h' do
    let(:expected_keys) do
      %i[
        kafka deserializers max_messages max_wait_time initial_offset id name active consumer
        consumer_group_id pause_max_timeout pause_timeout pause_with_exponential_backoff
        subscription_group_details active_job consumer_persistence dead_letter_queue declaratives
        inline_insights manual_offset_management eofed
      ]
    end

    it 'expect to contain all the topic attrs plus some inherited' do
      expect(topic.to_h.keys.sort).to eq(expected_keys.sort)
    end
  end
end
