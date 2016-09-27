RSpec.describe Karafka::Responders::Topic do
  subject(:topic) { described_class.new(name, options) }
  let(:name) { rand(1000).to_s }
  let(:options) { {} }

  pending
end
