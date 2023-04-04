# frozen_string_literal: true

RSpec.describe_current do
  subject(:selected_strategy) { described_class.new.find(topic) }

  let(:topic) { build(:routing_topic) }

  context 'when no features enabled' do
    it { expect(selected_strategy).to eq(Karafka::Processing::Strategies::Default) }
  end

  context 'when manual offset management is on' do
    before { topic.manual_offset_management(true) }

    it { expect(selected_strategy).to eq(Karafka::Processing::Strategies::Mom) }
  end

  context 'when dead letter queue is on' do
    before { topic.dead_letter_queue(topic: 'dead') }

    it { expect(selected_strategy).to eq(Karafka::Processing::Strategies::Dlq) }
  end

  context 'when dead letter queue is on with mom' do
    before do
      topic.dead_letter_queue(topic: 'dead')
      topic.manual_offset_management(true)
    end

    it { expect(selected_strategy).to eq(Karafka::Processing::Strategies::DlqMom) }
  end

  context 'when dead letter queue is on with mom and aj' do
    before do
      topic.active_job(true)
      topic.dead_letter_queue(topic: 'dead')
      topic.manual_offset_management(true)
    end

    it { expect(selected_strategy).to eq(Karafka::Processing::Strategies::AjDlqMom) }
  end

  context 'when mom is on with aj' do
    before do
      topic.active_job(true)
      topic.manual_offset_management(true)
    end

    it { expect(selected_strategy).to eq(Karafka::Processing::Strategies::AjMom) }
  end

  # Those specs make sure, that every expected features combination has a matching strategy
  # That way when we add a new feature, we can ensure, that all the combinations of features are
  # usable with it or that a given combination is one of the not supported or not needed
  #
  # We also need to prevent a case where a given combination would be defined twice by mistake, etc
  describe 'strategies presence vs. features combinations' do
    subject(:selector) { described_class.new }

    # Combinations that for any reason are not supported
    let(:not_used_combinations) do
      [
        # Active Job is always with manual offset management
        %i[active_job],
        # ActiveJob is always with MoM and when with DLQ, also MoM is needed
        %i[active_job dead_letter_queue]
      ]
    end

    let(:combinations) do
      combinations = []

      features = described_class::SUPPORTED_FEATURES

      features.size.times.each do |i|
        combinations += features.combination(i + 1).to_a
      end

      combinations.each(&:sort!)
      combinations.uniq!
      combinations
    end

    it 'expect each features combination to be supported expect the explicitly ignored' do
      combinations.each do |combination|
        matching_strategies = selector.strategies.select do |strategy|
          strategy::FEATURES.sort == combination
        end

        next if not_used_combinations.any? { |not_used| not_used.sort == combination }

        # Each combination of features should always have one matching strategy
        expect(matching_strategies.size).to eq(1)
      end
    end
  end
end
