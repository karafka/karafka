# frozen_string_literal: true

RSpec.describe Karafka::Routing::ShareGroups::Group do
  subject(:builder) { Karafka::Routing::Builder.new }

  after { builder.clear }

  let(:share_group) { builder.first }
  let(:consumer_class) { Class.new(Karafka::BaseConsumer) }

  context "when drawing a share group" do
    before do
      cclass = consumer_class

      builder.draw do
        share_group "webhooks" do
          topic :events do
            consumer cclass
          end
        end
      end
    end

    it "expect to build a share group" do
      expect(share_group).to be_a(described_class)
      expect(share_group.name).to eq("webhooks")
      expect(share_group.id).to eq("webhooks")
    end

    it "expect the share group to report the share group type" do
      expect(share_group.group_type).to eq(:share)
      expect(share_group).to be_share_group
      expect(share_group).not_to be_consumer_group
    end

    it "expect its topics to be share topics carrying the share group type" do
      topic = share_group.topics.first

      expect(topic).to be_a(Karafka::Routing::ShareGroups::Topic)
      expect(topic).not_to be_a(Karafka::Routing::Topic)
      expect(topic.group_type).to eq(:share)
    end

    it "expect App-like helpers to differentiate it from consumer groups" do
      expect(builder.select(&:share_group?)).to eq([share_group])
      expect(builder.select(&:consumer_group?)).to be_empty
    end
  end

  context "when share topics do not inherit consumer-group feature DSL" do
    let(:consumer_topic) { builder.find(&:consumer_group?).topics.first }
    let(:share_topic) { builder.find(&:share_group?).topics.first }

    before do
      cclass = consumer_class

      builder.draw do
        consumer_group "cg" do
          topic(:a) { consumer cclass }
        end

        share_group "sg" do
          topic(:b) { consumer cclass }
        end
      end
    end

    # Consumer-group-only routing features are prepended onto the consumer topic only and do not
    # leak onto the share topic. Features share groups also need (pausing, deserializers) are
    # duplicated under `Features::ShareGroups::*` and are covered separately below.
    %i[dead_letter_queue declaratives config].each do |feature|
      it "expect a consumer topic to respond to :#{feature} and a share topic not to" do
        expect(consumer_topic).to respond_to(feature)
        expect(share_topic).not_to respond_to(feature)
      end
    end

    # Pausing is provided for both modes in the same format (a per-mode `Pausing::Config` and a
    # `#pause` reader on each topic class), so share topics carry it just like consumer topics.
    it "expect both consumer and share topics to expose pausing" do
      expect(consumer_topic).to respond_to(:pause)
      expect(share_topic).to respond_to(:pause)
      expect(share_topic.pause).to be_a(Karafka::Routing::Features::ShareGroups::Pausing::Config)
    end

    # `active` is not an on/off switch here: it marks whether the settings were set explicitly for
    # this topic (`true`) or inherited from the global defaults (`false`). There is no per-topic
    # override path yet, so the inherited case is the only reachable one and is what we pin.
    it "expect the share topic pause config to be marked as inherited" do
      expect(share_topic.pause.active?).to be(false)
    end

    it "expect the share topic to_h to be frozen" do
      expect(share_topic.to_h).to be_frozen
    end

    # Deserializers are provided for both modes in the same format (a per-mode feature prepended
    # onto each topic class), since share groups also process message payloads, keys and headers.
    it "expect both consumer and share topics to expose active deserializers" do
      expect(consumer_topic).to respond_to(:deserializers)
      expect(share_topic).to respond_to(:deserializers)
      expect(share_topic.deserializers).to be_active
    end

    it "expect the share topic to_h to include pause and deserializers" do
      # The consumer-group feature is `deserializing` (it carries the extra `parallel` option),
      # while share groups keep the plain `deserializers` one, so the emitted keys differ
      expect(consumer_topic.to_h).to include(:deserializing, :pause)
      expect(share_topic.to_h).to include(:deserializers, :pause)
    end
  end

  context "when the global pause settings are customized" do
    let(:share_topic) { builder.find(&:share_group?).topics.first }
    let(:original_timeout) { Karafka::App.config.pause.timeout }
    let(:original_max_timeout) { Karafka::App.config.pause.max_timeout }
    let(:original_backoff) { Karafka::App.config.pause.with_exponential_backoff }

    # The pause config is built lazily and memoized the first time it is read, which happens while
    # the routes are drawn - so the global values have to be in place before `draw`. Distinct
    # values matter too: the suite pins timeout and max_timeout to the same number, so comparing
    # against the live config would pass even if the two reads were swapped.
    before do
      original_timeout
      original_max_timeout
      original_backoff

      Karafka::App.config.pause.timeout = 1_234
      Karafka::App.config.pause.max_timeout = 5_678
      Karafka::App.config.pause.with_exponential_backoff = true

      cclass = consumer_class

      builder.draw do
        share_group "sg" do
          topic(:b) { consumer cclass }
        end
      end
    end

    after do
      Karafka::App.config.pause.timeout = original_timeout
      Karafka::App.config.pause.max_timeout = original_max_timeout
      Karafka::App.config.pause.with_exponential_backoff = original_backoff
    end

    it "expect the share topic to inherit each global pause setting" do
      expect(share_topic.pause.timeout).to eq(1_234)
      expect(share_topic.pause.max_timeout).to eq(5_678)
      expect(share_topic.pause.with_exponential_backoff).to be(true)
    end
  end

  context "with backwards-compatible flat aliases" do
    it "expect Routing::ConsumerGroup to alias ConsumerGroups::Group" do
      expect(Karafka::Routing::ConsumerGroup).to equal(Karafka::Routing::ConsumerGroups::Group)
    end

    it "expect Routing::Topic to alias ConsumerGroups::Topic" do
      expect(Karafka::Routing::Topic).to equal(Karafka::Routing::ConsumerGroups::Topic)
    end
  end

  context "when a share group and a consumer group are drawn together" do
    it "expect both to validate and coexist" do
      cclass = consumer_class

      expect do
        builder.draw do
          consumer_group "orders" do
            topic(:orders) { consumer cclass }
          end

          share_group "webhooks" do
            topic(:webhooks) { consumer cclass }
          end
        end
      end.not_to raise_error

      expect(builder.map(&:group_type)).to match_array(%i[consumer share])
    end
  end

  context "when regexp-style topic definitions are used in a share group" do
    it "expect a Regexp topic reference to be rejected by the topic contract with a clear error" do
      cclass = consumer_class

      expect do
        builder.draw do
          share_group "sg" do
            topic(/events.*/) { consumer cclass }
          end
        end
      end.to raise_error(
        Karafka::Errors::InvalidConfigurationError,
        /regexp\/pattern topic subscriptions are not supported for share groups/
      )
    end

    it "expect a librdkafka-style '^' pattern string to be rejected with a clear error" do
      cclass = consumer_class

      expect do
        builder.draw do
          share_group "sg" do
            topic("^events-.*") { consumer cclass }
          end
        end
      end.to raise_error(
        Karafka::Errors::InvalidConfigurationError,
        /not supported for share groups/
      )
    end
  end
end
