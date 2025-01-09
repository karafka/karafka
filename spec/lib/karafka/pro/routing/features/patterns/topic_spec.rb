# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:topic) { build(:routing_topic) }

  describe '#patterns' do
    context 'when we use patterns without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.patterns.active?).to be(false)
      end
    end

    context 'when we use patterns with a active and a type' do
      it 'expect to use proper active status' do
        topic.patterns(active: true, type: 1)
        expect(topic.patterns.active?).to be(true)
      end
    end

    context 'when we use patterns multiple times with different values' do
      before do
        topic.patterns(active: true)
        topic.expire_in(false)
      end

      it 'expect to use proper active status' do
        expect(topic.patterns.active?).to be(true)
      end
    end
  end

  describe '#patterns?' do
    context 'when active' do
      before { topic.patterns(active: true) }

      it { expect(topic.patterns?).to be(true) }
    end

    context 'when not active' do
      before { topic.patterns }

      it { expect(topic.patterns?).to be(false) }
    end
  end

  describe '#active?' do
    context 'when there are no topics in the topics' do
      it { expect(topic.active?).to be(true) }
    end

    context 'when our topic name is in server topics' do
      before do
        Karafka::App
          .config
          .internal
          .routing
          .activity_manager
          .include(:topics, topic.name)
      end

      it { expect(topic.active?).to be(true) }
    end

    context 'when there is only a pattern matcher active topic and not in included' do
      before do
        topic.patterns.type = :matcher
        topic.patterns.active = true

        Karafka::App
          .config
          .internal
          .routing
          .activity_manager
          .include(:topics, 'z')
      end

      it 'expect not to be active because there is an explicit include request' do
        expect(topic.active?).to be(false)
      end
    end

    context 'when there is only a pattern matcher inactive topic and not in included' do
      before do
        topic.patterns.type = :matcher
        topic.patterns.active = true
        topic.active(false)

        Karafka::App
          .config
          .internal
          .routing
          .activity_manager
          .include(:topics, 'z')
      end

      it 'expect to always be active despite not being included' do
        expect(topic.active?).to be(false)
      end
    end

    context 'when there is only a pattern matcher active topic and not in excluded' do
      before do
        topic.patterns.type = :matcher
        topic.patterns.active = true

        Karafka::App
          .config
          .internal
          .routing
          .activity_manager
          .exclude(:topics, 'z')
      end

      it 'expect to always be active' do
        expect(topic.active?).to be(true)
      end
    end

    context 'when there is only a pattern matcher active topic and being in excluded' do
      before do
        topic.patterns.type = :matcher
        topic.patterns.active = true

        Karafka::App
          .config
          .internal
          .routing
          .activity_manager
          .exclude(:topics, topic.name)
      end

      it 'expect to not be active because it was explicitely excluded' do
        expect(topic.active?).to be(false)
      end
    end

    context 'when there is only a pattern matcher inactive topic and being in excluded' do
      before do
        topic.patterns.type = :matcher
        topic.patterns.active = false

        Karafka::App
          .config
          .internal
          .routing
          .activity_manager
          .exclude(:topics, topic.name)
      end

      it 'expect not to be active as it was switched to inactive' do
        expect(topic.active?).to be(false)
      end
    end

    context 'when our topic name is not in server topics' do
      before do
        Karafka::App
          .config
          .internal
          .routing
          .activity_manager
          .include(:topics, 'na')
      end

      it { expect(topic.active?).to be(false) }
    end

    context 'when we set the topic to active via #active' do
      before { topic.active(true) }

      it { expect(topic.active?).to be(true) }
    end

    context 'when we set the topic to inactive via #active' do
      before { topic.active(false) }

      it { expect(topic.active?).to be(false) }
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:patterns]).to eq(topic.patterns.to_h) }
  end

  describe '#subscription_name' do
    context 'when this is a regular topic' do
      it { expect(topic.subscription_name).to eq(topic.name) }
    end

    context 'when it is an active pattern matching topic' do
      before do
        topic.patterns(
          active: true,
          type: :matcher,
          pattern: ::Karafka::Pro::Routing::Features::Patterns::Pattern.new(nil, /xda/, -> {})
        )
      end

      it { expect(topic.subscription_name).to eq(topic.patterns.pattern.regexp_string) }
    end
  end
end
