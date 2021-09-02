# frozen_string_literal: true

RSpec.describe(
  'running a Karafka consumer to eat produced messages from earliest on a single partition',
  type: :integration
) do
  let(:numbers) { Array.new(100) { rand.to_s } }

  let(:consumer_class) do
    Class.new(Karafka::BaseConsumer) do
      def consume
        messages.each do |message|
          DataCollector.data[message.metadata.partition] << message.raw_payload
        end
      end
    end
  end

  before do
    topic_consumer = consumer_class

    Karafka::App.consumer_groups.re_draw do
      consumer_group DataCollector.topic do
        topic DataCollector.topic do
          consumer topic_consumer
        end
      end
    end

    Thread.new do
      sleep(0.1) while DataCollector.data[0].size < 100
      Karafka::App.stop!
    end

    numbers.each do |number|
      Karafka::App.producer.produce_async(
        topic: DataCollector.topic,
        payload: number
      )
    end

    Karafka::Server.run
  end

  it 'expect to receive data in correct order, amount and partition' do
    expect(DataCollector.data[0]).to eq(numbers)
    expect(DataCollector.data.size).to eq(1)
  end
end
