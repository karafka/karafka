# frozen_string_literal: true

RSpec.describe_current do
  strategies = Karafka::Pro::Processing::StrategySelector.new.strategies

  strategies
    .select { |strategy| strategy::FEATURES.include?(:virtual_partitions) }
    .each do |strategy|
      context "when having strategy #{strategy}" do
        it 'expect all of them to have #collapsed? method' do
          expect(strategy.method_defined?(:collapsed?)).to eq(true)
        end

        it 'expect all of them to have #failing? method' do
          expect(strategy.method_defined?(:failing?)).to eq(true)
        end
      end
    end
end
