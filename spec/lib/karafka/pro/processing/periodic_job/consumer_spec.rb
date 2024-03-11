# frozen_string_literal: true

RSpec.describe_current do
  let(:consumer_class) do
    Class.new(Karafka::BaseConsumer) do
      include Karafka::Pro::Processing::PeriodicJob::Consumer
    end
  end

  context 'when the consumer class does not define a #tick method' do
    it 'defines an empty #tick method upon inclusion of the module' do
      consumer_instance = consumer_class.new
      expect { consumer_instance.tick }.not_to raise_error
    end
  end

  context 'when the consumer class already defines a #tick method' do
    let(:consumer_class_with_tick) do
      klass = Class.new(Karafka::BaseConsumer) do
        def tick
          :existing_tick
        end
      end

      klass.include(Karafka::Pro::Processing::PeriodicJob::Consumer)

      klass
    end

    it 'does not override the existing #tick method' do
      consumer_instance = consumer_class_with_tick.new
      expect(consumer_instance.tick).to eq(:existing_tick)
    end
  end

  describe '#on_before_schedule_tick' do
    it 'calls handle_before_schedule_tick' do
      consumer_instance = consumer_class.new
      allow(consumer_instance).to receive(:handle_before_schedule_tick)

      consumer_instance.on_before_schedule_tick

      expect(consumer_instance).to have_received(:handle_before_schedule_tick)
    end
  end

  describe '#on_tick' do
    let(:error) { StandardError.new('tick error') }

    it 'calls handle_tick' do
      consumer_instance = consumer_class.new
      allow(consumer_instance).to receive(:handle_tick)

      consumer_instance.on_tick

      expect(consumer_instance).to have_received(:handle_tick)
    end

    it 'rescues from StandardError and instruments error' do
      consumer_instance = consumer_class.new
      allow(consumer_instance).to receive(:handle_tick).and_raise(error)
      allow(Karafka.monitor).to receive(:instrument)

      expect { consumer_instance.on_tick }.not_to raise_error
      expect(Karafka.monitor).to have_received(:instrument).with(
        'error.occurred',
        error: error,
        caller: consumer_instance,
        type: 'consumer.tick.error'
      )
    end
  end
end
