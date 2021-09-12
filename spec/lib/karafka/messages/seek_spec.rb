# frozen_string_literal: true

RSpec.describe_current do
  subject(:seek) { described_class.new(topic_name, partition, offset) }

  let(:topic_name) { rand.to_s }
  let(:partition) { rand(100) }
  let(:offset) { rand(100) }

  it { expect(seek.topic).to eq(topic_name) }
  it { expect(seek.partition).to eq(partition) }
  it { expect(seek.offset).to eq(offset) }
end
