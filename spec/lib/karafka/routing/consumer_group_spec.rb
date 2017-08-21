# frozen_string_literal: true

RSpec.describe Karafka::Routing::ConsumerGroup do
  subject(:consumer_group) { described_class.new(name) }

  let(:name) { rand.to_s }

  describe 'after initialize' do
    it 'expect not to have any topics yet' do
      expect(consumer_group.topics).to be_empty
    end
  end

  describe '#id' do
    it 'expect to namespace id with application client_id' do
      expect(consumer_group.id).to eq "#{Karafka::App.config.client_id.to_s.underscore}_#{name}"
    end
  end

  # We don't cover batch mode and topic mapper here as they don't come from kafka namespace of
  # configs but from the main namespace
  (
    Karafka::AttributesMap.consumer_group - %i[batch_consuming]
  ).each do |attribute|
    context attribute.to_s do
      it 'by default expect to fallback to a kafka config value' do
        expected_config_value = Karafka::App.config.kafka.public_send(attribute)
        expect(consumer_group.public_send(attribute)).to eq expected_config_value
      end
    end
  end

  %i[batch_consuming].each do |attribute|
    context attribute.to_s do
      it 'by default expect to fallback to a main config value' do
        expected_config_value = Karafka::App.config.public_send(attribute)
        expect(consumer_group.public_send(attribute)).to eq expected_config_value
      end
    end
  end

  describe '#topic=' do
    let(:built_topic) do
      # assigning block to a "=" method does not work normally
      consumer_group.public_send(:topic=, :topic_name) do
        controller Class.new
        worker Class.new
      end
    end

    before { built_topic }

    it { expect(consumer_group.topics.count).to eq 1 }
    it { expect(built_topic.name).to eq :topic_name.to_s }
  end

  describe '#active?' do
    context 'when there are no topics in the consumer group' do
      it { expect(consumer_group.active?).to eq false }
    end

    context 'when none of the topics is active' do
      before do
        consumer_group.public_send(:topic=, :topic_name) do
          controller Class.new
          worker Class.new
        end
      end

      it { expect(consumer_group.active?).to eq false }
    end

    context 'when our consumer group name is in server consumer groups' do
      before { Karafka::Server.consumer_groups = [name] }

      it { expect(consumer_group.active?).to eq true }
    end
  end

  describe '#to_h' do
    let(:casted_consumer_group) { consumer_group.to_h }

    Karafka::AttributesMap.consumer_group.each do |cg_attribute|
      it { expect(casted_consumer_group.keys).to include(cg_attribute) }
    end

    it { expect(casted_consumer_group.keys).to include(:topics) }
    it { expect(casted_consumer_group.keys).to include(:id) }

    context 'when there are topics inside' do
      let(:built_topic) do
        consumer_group.public_send(:topic=, :topic_name) do
          controller Class.new
          worker Class.new
        end
      end

      before { built_topic }

      it 'expect to have them casted to hash as well' do
        expect(casted_consumer_group[:topics].first).to eq built_topic.to_h
      end
    end
  end
end
