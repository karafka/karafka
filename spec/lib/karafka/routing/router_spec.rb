# frozen_string_literal: true

RSpec.describe Karafka::Routing::Router do
  subject(:router) { described_class }

  describe 'build' do
    context 'when we want to build a controller out of non existing topic' do
      let(:topic_id) { rand.to_s }
      let(:expected_error) { Karafka::Errors::NonMatchingRouteError }

      it { expect { router.build(topic_id) }.to raise_error(expected_error) }
    end

    context 'when we want to build controller out of an existing topic' do
      let(:topic) { Karafka::Routing::Builder.instance[0].topics[0] }
      let(:topic_id) { topic.id }

      before do
        Karafka::Routing::Builder.instance.draw do
          topic :topic_name1 do
            controller Struct.new(:topic)
            processing_adapter :inline
            name 'name1'
          end
        end
      end

      it do
        expect(router.build(topic_id)).to be_a(Struct)
        expect(router.build(topic_id).topic).to eq topic
      end
    end
  end
end
