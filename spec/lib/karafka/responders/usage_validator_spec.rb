RSpec.describe Karafka::Responders::UsageValidator do
  subject(:validator) { described_class.new(registered_topics, used_topics) }
  let(:topic_name) { "topic#{rand(1000)}" }
  let(:registered_topics) { { topic_name => Karafka::Responders::Topic.new(topic_name, {}) } }
  let(:used_topics) { [rand] }

  describe '#validate!' do
    it 'expect to run validations on used and registered topics' do
      expect(validator).to receive(:validate_usage_of!)
        .with(used_topics.first)
      expect(validator).to receive(:validate_requirements_of!)
        .with(registered_topics.first.last)

      validator.validate!
    end
  end

  describe '#validate_usage_of!' do
    context 'when we used topic that was not registered' do
      let(:invalid_topic_name) { "notregistered#{rand(1000)}" }
      let(:error) { Karafka::Errors::UnregisteredTopic }

      it do
        expect { validator.send(:validate_usage_of!, invalid_topic_name) }.to raise_error error
      end
    end

    context 'when we used registered topic' do
      context 'and it was used once' do
        it { expect { validator.send(:validate_usage_of!, topic_name) }.not_to raise_error }
      end

      context 'and we used it multiple times' do
        let(:used_topics) { [topic_name, topic_name] }

        context 'but it as not marked as multiple' do
          let(:registered_topics) do
            { topic_name => Karafka::Responders::Topic.new(topic_name, multiple_usage: false) }
          end
          let(:error) { Karafka::Errors::TopicMultipleUsage }

          it { expect { validator.send(:validate_usage_of!, topic_name) }.to raise_error error }
        end

        context 'and it was marked as multiple' do
          let(:registered_topics) do
            { topic_name => Karafka::Responders::Topic.new(topic_name, multiple_usage: true) }
          end

          it { expect { validator.send(:validate_usage_of!, topic_name) }.not_to raise_error }
        end
      end
    end
  end

  describe '#validate_requirements_of!' do
    let(:registered_topic) { registered_topics[topic_name] }

    context 'when topic usage was optional' do
      let(:registered_topics) do
        { topic_name => Karafka::Responders::Topic.new(topic_name, optional: true) }
      end

      context 'and it was not used' do
        it do
          expectation = expect { validator.send(:validate_requirements_of!, registered_topic) }
          expectation.not_to raise_error
        end
      end
    end

    context 'when topic was required' do
      let(:registered_topics) do
        { topic_name => Karafka::Responders::Topic.new(topic_name, required: true) }
      end

      context 'and it was used' do
        let(:used_topics) { [topic_name] }

        it do
          expectation = expect { validator.send(:validate_requirements_of!, registered_topic) }
          expectation.not_to raise_error
        end
      end

      context 'and it was not used' do
        let(:used_topics) { [] }
        let(:error) { Karafka::Errors::UnusedResponderRequiredTopic }

        it do
          expectation = expect { validator.send(:validate_requirements_of!, registered_topic) }
          expectation.to raise_error error
        end
      end
    end
  end
end
