# frozen_string_literal: true

RSpec.describe Karafka::Routing::Router do
  subject(:router) { described_class }

  let(:partition) { rand(100) }
  let(:kafka_message) do
    instance_double(
      Kafka::FetchedMessage,
      partition: partition,
      topic: topic_name
    )
  end

  describe 'build' do
    context 'not persisted' do
      context 'when we want to build a controller out of non existing topic' do
        let(:group_id) { rand.to_s }
        let(:topic_name) { rand.to_s }
        let(:expected_error) { Karafka::Errors::NonMatchingRouteError }

        it { expect { router.build(group_id, kafka_message) }.to raise_error(expected_error) }
      end

      context 'when we want to build controller out of an existing topic' do
        let(:group_id) { Karafka::Routing::Builder.instance[0].topics[0].consumer_group.id }
        let(:topic_name) { 'topic_name1' }

        before do
          Karafka::Routing::Builder.instance.draw do
            topic :topic_name1 do
              controller Class.new(Karafka::BaseController)
              processing_backend :inline
            end
          end
        end

        it do
          expect(router.build(group_id, kafka_message)).to be_a(Karafka::BaseController)
        end
      end
    end

    context 'persisted' do
      pending
    end
  end
end
