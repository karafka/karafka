RSpec.describe Karafka::BaseResponder do
  let(:working_class) do
    ClassBuilder.inherit(described_class) do
      def perform
        self
      end
    end
  end

  pending
end
