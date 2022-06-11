# frozen_string_literal: true

require 'karafka/pro/routing/extensions'

RSpec.describe_current do
  subject(:extended_topic) do
    build(:routing_topic).tap do |topic|
      topic.singleton_class.include Karafka::Pro::Routing::Extensions
    end
  end

  it 'expect not to use lrj by defaulr' do
    expect(extended_topic.long_running_job?).to eq(false)
  end

  context 'when lrj is set' do
    before { extended_topic.long_running_job = true }

    it { expect(extended_topic.long_running_job?).to eq(true) }
  end
end
