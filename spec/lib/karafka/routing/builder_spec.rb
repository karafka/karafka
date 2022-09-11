# frozen_string_literal: true

RSpec.describe_current do
  subject(:builder) { described_class.new }

  before { builder.clear }

  after { builder.clear }

  describe '#draw' do
    context 'when we use simple topic style' do
      let(:topic1) { builder.first.topics.first }
      let(:topic2) { builder.last.topics.last }
      let(:draw1) do
        builder.draw do
          topic :topic_name1 do
            # Here we should have instance doubles, etc but it takes
            # shitload of time to setup instance evaluation from instance variables,
            # so instead we check against constant names
            consumer Class.new(Karafka::BaseConsumer)
            deserializer :deserializer1
          end
        end
      end
      let(:draw2) do
        builder.draw do
          topic :topic_name2 do
            consumer Class.new(Karafka::BaseConsumer)
            deserializer :deserializer2
          end
        end
      end

      before do
        draw1
        draw2
      end

      # This needs to have twice same name as for a non grouped in consumer group topics,
      # we build id based on the consumer group id, here it is virtual and built with 'app' as a
      # group name
      it { expect(topic1.id).to eq "#{Karafka::App.config.client_id}_app_topic_name1" }
      it { expect(topic2.id).to eq "#{Karafka::App.config.client_id}_app_topic_name2" }
      it { expect(builder.size).to eq 1 }
      it { expect(topic1.subscription_group).to eq nil }
      it { expect(topic1.name).to eq 'topic_name1' }
      it { expect(topic2.name).to eq 'topic_name2' }
      it { expect(topic2.subscription_group).to eq nil }
      it { expect(builder.first.id).to eq "#{Karafka::App.config.client_id}_app" }
    end

    context 'when we use simple topic style with one subscription group and one topic' do
      let(:topic) { builder.first.topics.first }
      let(:draw) do
        builder.draw do
          subscription_group 'test' do
            topic :topic_name1 do
              consumer Class.new(Karafka::BaseConsumer)
              deserializer :deserializer1
            end
          end
        end
      end

      before { draw }

      it { expect(topic.subscription_group).to eq 'test' }
    end

    context 'when we use simple topic style with one subscription group and two topics' do
      let(:topic1) { builder.first.topics.first }
      let(:topic2) { builder.first.topics.last }
      let(:draw) do
        builder.draw do
          subscription_group 'test' do
            topic :topic_name1 do
              consumer Class.new(Karafka::BaseConsumer)
              deserializer :deserializer1
            end

            topic :topic_name2 do
              consumer Class.new(Karafka::BaseConsumer)
              deserializer :deserializer1
            end
          end
        end
      end

      before { draw }

      it { expect(topic1.subscription_group).to eq 'test' }
      it { expect(topic2.subscription_group).to eq 'test' }
    end

    context 'when we use simple topic style with many subscription groups' do
      let(:topic1) { builder.first.topics.first }
      let(:topic2) { builder.first.topics.last }
      let(:draw) do
        builder.draw do
          subscription_group 'test1' do
            topic :topic_name1 do
              consumer Class.new(Karafka::BaseConsumer)
              deserializer :deserializer1
            end
          end

          subscription_group 'test2' do
            topic :topic_name2 do
              consumer Class.new(Karafka::BaseConsumer)
              deserializer :deserializer1
            end
          end
        end
      end

      before { draw }

      it { expect(topic1.subscription_group).to eq 'test1' }
      it { expect(topic2.subscription_group).to eq 'test2' }
    end

    context 'when we mix subscription group definitions styles' do
      let(:topic1) { builder.first.topics.first }
      let(:topic2) { builder.first.topics.last }
      let(:draw) do
        builder.draw do
          subscription_group 'test1' do
            topic :topic_name1 do
              consumer Class.new(Karafka::BaseConsumer)
              deserializer :deserializer1
            end
          end

          topic :topic_name2 do
            consumer Class.new(Karafka::BaseConsumer)
            deserializer :deserializer1
          end
        end
      end

      before { draw }

      it { expect(topic1.subscription_group).to eq 'test1' }
      it { expect(topic2.subscription_group).to eq nil }
    end

    context 'when we use 0.6 simple topic style single topic groups' do
      let(:topic1) { builder.first.topics.first }
      let(:topic2) { builder.last.topics.first }
      let(:consumer_group1) do
        builder.draw do
          consumer_group :group_name1 do
            topic :topic_name1 do
              kafka('bootstrap.servers' => 'localhost:9092')
              consumer Class.new(Karafka::BaseConsumer)
              deserializer :deserializer1
            end
          end
        end
      end
      let(:consumer_group2) do
        builder.draw do
          consumer_group :group_name2 do
            topic :topic_name2 do
              kafka('bootstrap.servers' => 'localhost:9093')
              consumer Class.new(Karafka::BaseConsumer)
              deserializer :deserializer2
            end
          end
        end
      end

      before do
        consumer_group1
        consumer_group2
      end

      it { expect(topic1.id).to eq "#{Karafka::App.config.client_id}_group_name1_topic_name1" }
      it { expect(topic1.subscription_group).to eq nil }
      it { expect(topic2.id).to eq "#{Karafka::App.config.client_id}_group_name2_topic_name2" }
      it { expect(topic2.subscription_group).to eq nil }
      it { expect(builder.size).to eq 2 }
    end

    context 'when we use 0.6 simple topic style multiple topic group' do
      let(:topic1) { builder.first.topics.first }
      let(:topic2) { builder.first.topics.last }

      before do
        builder.draw do
          consumer_group :group_name1 do
            topic :topic_name1 do
              kafka('bootstrap.servers' => 'localhost:9092')
              consumer Class.new(Karafka::BaseConsumer)
              deserializer :deserializer1
            end

            topic :topic_name2 do
              kafka('bootstrap.servers' => 'localhost:9092')
              consumer Class.new(Karafka::BaseConsumer)
              deserializer :deserializer2
            end
          end
        end
      end

      it { expect(topic1.id).to eq "#{Karafka::App.config.client_id}_group_name1_topic_name1" }
      it { expect(topic2.id).to eq "#{Karafka::App.config.client_id}_group_name1_topic_name2" }
      it { expect(builder.size).to eq 1 }
    end

    context 'when we define multiple consumer groups with multiple subscription groups' do
      let(:topic1) { builder.first.topics.first }
      let(:topic2) { builder.last.topics.last }

      before do
        builder.draw do
          consumer_group :group_name1 do
            subscription_group 'test1' do
              topic :topic_name1 do
                kafka('bootstrap.servers' => 'localhost:9092')
                consumer Class.new(Karafka::BaseConsumer)
                deserializer :deserializer1
              end
            end
          end

          consumer_group :group_name2 do
            subscription_group 'test2' do
              topic :topic_name2 do
                kafka('bootstrap.servers' => 'localhost:9092')
                consumer Class.new(Karafka::BaseConsumer)
                deserializer :deserializer2
              end
            end
          end
        end
      end

      it { expect(topic1.id).to eq "#{Karafka::App.config.client_id}_group_name1_topic_name1" }
      it { expect(topic2.id).to eq "#{Karafka::App.config.client_id}_group_name2_topic_name2" }
      it { expect(builder.size).to eq 2 }
    end

    context 'when we define invalid route' do
      let(:invalid_route) do
        builder.draw do
          consumer_group '$%^&*(' do
            topic :topic_name1 do
              deserializer :deserializer1
            end
          end
        end
      end

      it { expect { invalid_route }.to raise_error(Karafka::Errors::InvalidConfigurationError) }
    end

    context 'when we define multiple consumer groups and one is without topics' do
      subject(:drawing) do
        builder.draw do
          consumer_group :group_name1 do
            topic(:topic_name1) { consumer Class.new(Karafka::BaseConsumer) }
          end

          consumer_group(:group_name2) {}
        end
      end

      it { expect { drawing }.to raise_error(Karafka::Errors::InvalidConfigurationError) }
    end
  end

  describe '#active' do
    let(:active_group) { instance_double(Karafka::Routing::ConsumerGroup, active?: true) }
    let(:inactive_group) { instance_double(Karafka::Routing::ConsumerGroup, active?: false) }

    before do
      builder << active_group
      builder << inactive_group
    end

    it 'expect to select only active consumer groups' do
      expect(builder.active).to eq [active_group]
    end
  end
end
