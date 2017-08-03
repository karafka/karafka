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

      context 'and it was supposed to be used multiple times' do
        context 'and we used it once' do
          let(:used_topics) { [topic_name] }

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
        { topic_name => Karafka::Responders::Topic.new(topic_name, required: false) }
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
=end