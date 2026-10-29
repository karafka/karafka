# frozen_string_literal: true

RSpec.describe_current do
  subject(:validation) { described_class.new.call(config) }

  let(:config) { { acknowledgements: { active: true, unacknowledged: :release } } }

  context "when config is valid" do
    it { expect(validation).to be_success }
  end

  %i[accept reject].each do |state|
    context "when unacknowledged is #{state}" do
      before { config[:acknowledgements][:unacknowledged] = state }

      it { expect(validation).to be_success }
    end
  end

  context "when unacknowledged is not supported" do
    before { config[:acknowledgements][:unacknowledged] = :renew }

    it { expect(validation).not_to be_success }
  end

  context "when active is not true" do
    before { config[:acknowledgements][:active] = false }

    it { expect(validation).not_to be_success }
  end
end
