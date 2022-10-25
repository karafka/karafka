# frozen_string_literal: true

RSpec.describe_current do
  it { expect(described_class).to be < ::Karafka::Pro::Routing::Features::Base }
end
