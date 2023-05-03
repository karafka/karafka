# frozen_string_literal: true

RSpec.describe_current do
  let(:message) { build(:messages_message) }
  let(:coordinator) { build(:processing_coordinator_pro, seek_offset: 0, topic: topic) }
  let(:topic) { build(:routing_topic) }
  let(:client) { instance_double(Karafka::Connection::Client, pause: true) }
  let(:consumer) do
    consumer = Karafka::BaseConsumer.new
    consumer.client = client
    consumer.coordinator = coordinator
    consumer.messages = [message]
    consumer
  end

  strategies = Karafka::Pro::Processing::StrategySelector.new.strategies

  strategies
    .select { |strategy| strategy::FEATURES.include?(:virtual_partitions) }
    .each do |strategy|
      context "when having VP strategy: #{strategy}" do
        let(:topic) do
          topic = build(:routing_topic)
          topic.virtual_partitions(partitioner: true)
          topic
        end

        it 'expect all of them to have #collapsed? method' do
          expect(strategy.method_defined?(:collapsed?)).to eq(true)
        end

        it 'expect all of them to have #failing? method' do
          expect(strategy.method_defined?(:failing?)).to eq(true)
        end

        context 'when using VPs and VPs virtual marking' do
          before { consumer.singleton_class.include(strategy) }

          it 'expect its #handle_before_enqueue to always register virtual offsets groups' do
            consumer.send(:handle_before_enqueue)

            expect(coordinator.virtual_offset_manager.groups).not_to be_empty
          end
        end
      end
    end

  strategies
    .select { |strategy| strategy::FEATURES.include?(:virtual_partitions) }
    .select { |strategy| strategy::FEATURES.include?(:dead_letter_queue) }
    .each do |strategy|
      context "when having DLQ and VP strategy: #{strategy}" do
        it 'expect to include the Dlq::Vp strategy in the chain' do
          expect(strategy.ancestors).to include(::Karafka::Pro::Processing::Strategies::Dlq::Vp)
        end
      end
    end

  strategies
    .reject { |strategy| strategy::FEATURES.include?(:virtual_partitions) }
    .each do |strategy|
      context "when having non-VP strategy: #{strategy}" do
        before { consumer.singleton_class.include(strategy) }

        it 'expect not to have any VP related components' do
          strategy.ancestors.each do |ancestor|
            next if ancestor.to_s.end_with?('::Base')

            expect(ancestor::FEATURES).not_to include(:virtual_partitions)
            expect(ancestor.to_s).not_to include('::Vp')
          end
        end

        it 'expect its #handle_before_enqueue to never register virtual offsets groups' do
          consumer.send(:handle_before_enqueue)

          expect(coordinator.virtual_offset_manager).to be_nil
        end

        it 'expect its #handle_before_enqueue to not fail without virtual_offset_manager' do
          expect { consumer.send(:handle_before_enqueue) }.not_to raise_error
        end
      end
    end

  strategies
    .select { |strategy| strategy::FEATURES.include?(:long_running_job) }
    .each do |strategy|
      context "when having an LRJ strategy: #{strategy}" do
        let(:topic) do
          topic = build(:routing_topic)
          topic.virtual_partitions(partitioner: true) if strategy.to_s.include?('Vp')
          topic
        end

        before do
          consumer.singleton_class.include(strategy)
          allow(client).to receive(:pause)
        end

        it 'expect its #handle_before_enqueue to invoke pause on a client' do
          consumer.send(:handle_before_enqueue)

          expect(client).to have_received(:pause)
        end
      end
    end

  strategies
    .reject { |strategy| strategy::FEATURES.include?(:long_running_job) }
    .each do |strategy|
      context "when having a non LRJ strategy: #{strategy}" do
        let(:topic) do
          topic = build(:routing_topic)
          topic.virtual_partitions(partitioner: true) if strategy.to_s.include?('Vp')
          topic
        end

        before do
          consumer.singleton_class.include(strategy)
          allow(client).to receive(:pause)
        end

        it 'expect its #handle_before_enqueue to never invoke pause on a client' do
          consumer.send(:handle_before_enqueue)

          expect(client).not_to have_received(:pause)
        end
      end
    end
end
