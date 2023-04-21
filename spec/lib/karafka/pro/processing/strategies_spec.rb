# frozen_string_literal: true

RSpec.describe_current do
  strategies = Karafka::Pro::Processing::StrategySelector.new.strategies

  strategies
    .select { |strategy| strategy::FEATURES.include?(:virtual_partitions) }
    .each do |strategy|
      context "when having VP strategy #{strategy}" do
        it 'expect all of them to have #collapsed? method' do
          expect(strategy.method_defined?(:collapsed?)).to eq(true)
        end

        it 'expect all of them to have #failing? method' do
          expect(strategy.method_defined?(:failing?)).to eq(true)
        end
      end
    end

  strategies
    .select { |strategy| !strategy::FEATURES.include?(:virtual_partitions) }
    .each do |strategy|
      context "when having non-VP strategy: #{strategy}" do
        it 'expect not to have any VP related components' do
          strategy.ancestors.each do |ancestor|
            next if ancestor.to_s.end_with?('::Base')

            expect(ancestor::FEATURES).not_to include(:virtual_partitions)
            expect(ancestor.to_s).not_to include('::Vp')
          end
        end
      end
    end
end
