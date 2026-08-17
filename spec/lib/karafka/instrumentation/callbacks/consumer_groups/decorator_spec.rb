# frozen_string_literal: true

RSpec.describe_current do
  subject(:decorator) { described_class.new }

  it { expect(described_class).to be < Karafka::Core::Monitoring::StatisticsDecorator }

  describe "#call" do
    let(:statistics) { { "msg_count" => 1 } }

    it "decorates exactly like the base StatisticsDecorator" do
      expect(decorator.call(statistics)).to eq(
        "msg_count" => 1,
        "msg_count_fd" => 0,
        "msg_count_d" => 0
      )
    end
  end
end
