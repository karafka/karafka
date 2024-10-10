# frozen_string_literal: true

module Karafka
  module Contracts
    # Ensures that routing wide rules are obeyed
    class Routing < Base
      configure do |config|
        config.error_messages = YAML.safe_load(
          File.read(
            File.join(Karafka.gem_root, 'config', 'locales', 'errors.yml')
          )
        ).fetch('en').fetch('validations').fetch('routing')
      end

      # Ensures, that when declarative topics strict requirement is on, all topics have
      # declarative definition (including DLQ topics)
      # @note It will ignore routing pattern topics because those topics are virtual
      virtual do |data, errors|
        next unless errors.empty?
        # Do not validate declaratives unless required and explicitly enabled
        next unless Karafka::App.config.strict_declarative_topics

        # Collects declarative topics. Please note, that any topic that has a `#topic` reference,
        # will be declarative by default unless explicitly disabled. This however does not apply
        # to the DLQ definitions
        dec_topics = Set.new
        # All topics including the DLQ topics names that are marked as active
        topics = Set.new

        data.each do |consumer_group|
          consumer_group[:topics].each do |topic|
            pat = topic[:patterns]
            # Ignore pattern topics because they won't exist and should not be declarative
            # managed
            topics << topic[:name] if !pat || !pat[:active]

            dlq = topic[:dead_letter_queue]
            topics << dlq[:topic] if dlq[:active]

            dec = topic[:declaratives]

            dec_topics << topic[:name] if dec[:active]
          end
        end

        missing_dec = topics - dec_topics

        next if missing_dec.empty?

        missing_dec.map do |topic_name|
          [
            [:topics, topic_name],
            :without_declarative_definition
          ]
        end
      end
    end
  end
end
