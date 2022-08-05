# frozen_string_literal: true

RSpec.describe_current do
  let(:name) { SecureRandom.uuid }
  let(:topics) { Karafka::Admin.cluster_info.topics.map { |tp| tp[:topic_name] } }

  describe '#create_topic and #cluster_info' do
    context 'when creating topic with one partition' do
      before { described_class.create_topic(name, 1, 1) }

      it { expect(topics).to include(name) }
    end

    context 'when creating topic with two partitions' do
      before { described_class.create_topic(name, 2, 1) }

      it { expect(topics).to include(name) }
    end
  end

  describe '#delete_topic and #cluster_info' do
    before do
      described_class.create_topic(name, 2, 1)
      described_class.delete_topic(name)
    end

    it { expect(topics).not_to include(name) }
  end
end
