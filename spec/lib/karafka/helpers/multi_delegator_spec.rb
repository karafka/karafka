RSpec.describe Karafka::Helpers::MultiDelegator do
  let(:methods) { [:"m1#{rand(1000)}", :"m2#{rand(1000)}"] }

  2.times do |i|
    let(:"target#{i + 1}") do
      meth = {}
      methods.each do |method|
        meth[method] = rand
      end

      Struct.new(*meth.keys).new(*meth.values)
    end
  end

  describe 'delegation' do
    subject(:delegator) do
      described_class
        .delegate(*methods)
        .to(target1, target2)
    end

    it 'delegates to all' do
      methods.each do |mname|
        expect(target1).to receive(mname)
        expect(target2).to receive(mname)

        delegator.send(mname)
      end
    end
  end
end
