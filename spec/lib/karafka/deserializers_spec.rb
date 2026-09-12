# frozen_string_literal: true

RSpec.describe_current do
  it "is a backwards compatible alias for Karafka::Deserializing::Deserializers" do
    expect(described_class).to equal(Karafka::Deserializing::Deserializers)
  end

  it "exposes the default deserializers under the pre-2.6.2 namespace" do
    expect(described_class::Payload).to equal(Karafka::Deserializing::Deserializers::Payload)
    expect(described_class::Key).to equal(Karafka::Deserializing::Deserializers::Key)
    expect(described_class::Headers).to equal(Karafka::Deserializing::Deserializers::Headers)
  end
end
