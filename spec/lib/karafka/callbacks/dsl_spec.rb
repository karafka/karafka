# frozen_string_literal: true

RSpec.describe Karafka::Callbacks::Dsl do
  # App gets dsl, so it is easier to test against it
  subject(:app_class) { Karafka::App }

  describe '#after_init' do
    let(:execution_block) { ->(_config) {} }

    it 'expects to subscribe to app.after_init event' do
      expect(Karafka.event_publisher).to receive(:subscribe).with('app.after_init')
      app_class.after_init(&execution_block)
    end

    it 'keeps backward-compatibility' do
      app_class.after_init(&execution_block)

      expect { Karafka.event_publisher.publish('app.after_init', config: {}) }.not_to raise_error
    end
  end

  describe '#before_fetch_loop' do
    let(:execution_block) { ->(_consumer_group, _client) {} }

    it 'expects to subscribe to connection.listener.before_fetch_loop event' do
      expect(Karafka.event_publisher).to(
        receive(:subscribe).with('connection.listener.before_fetch_loop')
      )
      app_class.before_fetch_loop(&execution_block)
    end

    it 'keeps backward-compatibility' do
      app_class.before_fetch_loop(&execution_block)

      expect do
        Karafka.event_publisher.publish(
          'connection.listener.before_fetch_loop',
          consumer_group: double,
          client: double
        )
      end.not_to raise_error
    end
  end
end
