# frozen_string_literal: true

RSpec.describe_current do
  subject(:builder) { Karafka::Routing::Builder.new }

  before { builder.clear }

  after { builder.clear }

  context 'when we define active job topic on the root level with other topics' do
    let(:topic1) { builder.first.topics.first }
    let(:topic2) { builder.first.topics.last }

    before do
      builder.draw do
        active_job_topic :default

        topic :topic_name do
          consumer Class.new(Karafka::BaseConsumer)
        end
      end
    end

    it { expect(topic1.id).to eq "#{Karafka::App.config.client_id}_app_default" }
    it { expect(topic2.id).to eq "#{Karafka::App.config.client_id}_app_topic_name" }
    it { expect(builder.size).to eq 1 }
    it { expect(topic1.consumer).to eq(Karafka::ActiveJob::Consumer) }
    it { expect(topic2.consumer).not_to eq(Karafka::ActiveJob::Consumer) }
  end

  context 'when we define more than one active job topic on the root level without other topics' do
    let(:topic1) { builder.first.topics.first }
    let(:topic2) { builder.first.topics.last }

    before do
      builder.draw do
        active_job_topic :default
        active_job_topic :urgent
      end
    end

    it { expect(topic1.id).to eq "#{Karafka::App.config.client_id}_app_default" }
    it { expect(topic2.id).to eq "#{Karafka::App.config.client_id}_app_urgent" }
    it { expect(builder.size).to eq 1 }
    it { expect(topic1.consumer).to eq(Karafka::ActiveJob::Consumer) }
    it { expect(topic2.consumer).to eq(Karafka::ActiveJob::Consumer) }
  end

  context 'when we define separate consumer groups for separate active job topics' do
    let(:topic1) { builder.first.topics.first }
    let(:topic2) { builder.last.topics.last }

    before do
      builder.draw do
        consumer_group :g1 do
          active_job_topic :default
        end

        consumer_group :g2 do
          active_job_topic :urgent
        end
      end
    end

    it { expect(topic1.id).to eq "#{Karafka::App.config.client_id}_g1_default" }
    it { expect(topic2.id).to eq "#{Karafka::App.config.client_id}_g2_urgent" }
    it { expect(builder.size).to eq 2 }
    it { expect(topic1.consumer).to eq(Karafka::ActiveJob::Consumer) }
    it { expect(topic2.consumer).to eq(Karafka::ActiveJob::Consumer) }
  end
end
