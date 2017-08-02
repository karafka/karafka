# frozen_string_literal: true

RSpec.describe Karafka::Routing::Builder do
  subject(:builder) { described_class.instance }

  ATTRIBUTES = %i[
    controller
    inline_mode
    name
    worker
    parser
    interchanger
    responder
  ]

  before(:each) do
    # Unfreezing so we can run multiple checks on a singleton
    Fiddle::Pointer.new(builder.object_id * 2)[1] &= ~(1 << 3)
    builder.clear
  end

  describe '#draw' do
    context '0.5 compatible simple topic style' do
      let(:topic1) { builder.first.topics.first }
      let(:topic2) { builder.last.topics.first }

      before do
        described_class.instance.draw do
          topic :topic_name1 do
            # Here we should have instance doubles, etc but it takes
            # shitload of time to setup to pass to instance eval from instance variables,
            # so instead we check against constant names
            controller :controller1
            inline_mode :inline_mode1
            name :name1
            worker :worker1
            parser :parser1
            interchanger :interchanger1
            responder :responder1
          end

          topic :topic_name2 do
            # Here we should have instance doubles, etc but it takes
            # shitload of time to setup to pass to instance eval from instance variables,
            # so instead we check against constant names
            controller :controller2
            inline_mode :inline_mode2
            name :name2
            worker :worker2
            parser :parser2
            interchanger :interchanger2
            responder :responder2
          end
        end
      end

      ATTRIBUTES.each do |attr|
        it { expect(topic1.public_send(attr)).to eq :"#{attr}1" }
        it { expect(topic2.public_send(attr)).to eq :"#{attr}2" }
      end

      # This needs to have twice same name as for a non grouped in consumer group topics,
      # we build id based on the consumer group id, here it is virtual and built based on the
      # topic name
      it { expect(topic1.id).to eq "#{Karafka::App.config.name}_topic_name1_topic_name1" }
      it { expect(topic2.id).to eq "#{Karafka::App.config.name}_topic_name2_topic_name2" }
      it { expect(builder.size).to eq 2 }
    end

    context '0.6 simple topic style single topic groups' do
      let(:topic1) { builder.first.topics.first }
      let(:topic2) { builder.last.topics.first }

      before do
        described_class.instance.draw do
          consumer_group :group_name1 do
            seed_brokers [:brokers1]

            topic :topic_name1 do
              controller :controller1
              inline_mode :inline_mode1
              name :name1
              worker :worker1
              parser :parser1
              interchanger :interchanger1
              responder :responder1
            end
          end

          consumer_group :group_name2 do
            seed_brokers [:brokers2]

            topic :topic_name2 do
              controller :controller2
              inline_mode :inline_mode2
              name :name2
              worker :worker2
              parser :parser2
              interchanger :interchanger2
              responder :responder2
            end
          end
        end
      end

      ATTRIBUTES.each do |attr|
        it { expect(topic1.public_send(attr)).to eq :"#{attr}1" }
        it { expect(topic2.public_send(attr)).to eq :"#{attr}2" }
      end

      it { expect(topic1.id).to eq "#{Karafka::App.config.name}_group_name1_topic_name1" }
      it { expect(topic2.id).to eq "#{Karafka::App.config.name}_group_name2_topic_name2" }
      it { expect(builder.first.seed_brokers).to eq [:brokers1] }
      it { expect(builder.last.seed_brokers).to eq [:brokers2] }
      it { expect(builder.size).to eq 2 }
    end

    context '0.6 simple topic style multiple topic group' do
      let(:topic1) { builder.first.topics.first }
      let(:topic2) { builder.first.topics.last }

      before do
        described_class.instance.draw do
          consumer_group :group_name1 do
            seed_brokers [:brokers]

            topic :topic_name1 do
              controller :controller1
              inline_mode :inline_mode1
              name :name1
              worker :worker1
              parser :parser1
              interchanger :interchanger1
              responder :responder1
            end

            topic :topic_name2 do
              controller :controller2
              inline_mode :inline_mode2
              name :name2
              worker :worker2
              parser :parser2
              interchanger :interchanger2
              responder :responder2
            end
          end
        end
      end

      ATTRIBUTES.each do |attr|
        it { expect(topic1.public_send(attr)).to eq :"#{attr}1" }
        it { expect(topic2.public_send(attr)).to eq :"#{attr}2" }
      end

      it { expect(topic1.id).to eq "#{Karafka::App.config.name}_group_name1_topic_name1" }
      it { expect(topic2.id).to eq "#{Karafka::App.config.name}_group_name1_topic_name2" }
      it { expect(builder.first.seed_brokers).to eq [:brokers] }
      it { expect(builder.size).to eq 1 }
    end

    context 'invalid route' do
      let(:invalid_route) do
        described_class.instance.draw do
          consumer_group '$%^&*(' do
            topic :topic_name1 do
              inline_mode true
            end
          end
        end
      end

      it { expect { invalid_route }.to raise_error(Karafka::Errors::InvalidConfiguration) }
    end
  end
end
