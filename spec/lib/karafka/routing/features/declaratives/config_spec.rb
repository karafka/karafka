# frozen_string_literal: true

RSpec.describe Karafka::Routing::Features::Declaratives::Config do
  it "is an alias for Karafka::Declaratives::Topic" do
    expect(described_class).to eq(Karafka::Declaratives::Topic)
  end
end
