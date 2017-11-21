# frozen_string_literal: true

RSpec.describe Karafka::Routing::Router do
  subject(:router) { described_class }

  before do
    Karafka::Routing::Builder.instance.delete_if { true }

    Karafka::Routing::Builder.instance.draw do
      topic :topic_name1 do
        controller Class.new(Karafka::BaseController)
        persistent false
        batch_consuming true
      end
    end
  end

  describe 'find' do
    context 'when we look for non existing topic' do
      let(:topic_id) { rand.to_s }
      let(:expected_error) { Karafka::Errors::NonMatchingRouteError }

      it { expect { router.find(topic_id) }.to raise_error(expected_error) }
    end

    context 'when we look for existing topic' do
      let(:topic) { Karafka::Routing::Builder.instance.last.topics.last }
      let(:topic_id) { topic.id }

      it { expect(router.find(topic_id)).to eq topic }
    end
  end
end
