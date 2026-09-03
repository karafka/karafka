# frozen_string_literal: true

module Karafka
  module Routing
    class Topics
      # Base class for the routing topic types. It stores all the mode-agnostic details on how we
      # should interact with a given Kafka topic and is a part of Karafka's DSL.
      #
      # Concrete topic types ({Karafka::Routing::Topic} for consumer groups and
      # {Topics::ShareTopic} for share groups) inherit from it. Consumer-group routing features are
      # prepended onto {Karafka::Routing::Topic} only, so share topics deliberately do not inherit
      # consumer-group feature flow.
      #
      # @note `#group` is the polymorphic reference to the owning group. `#consumer_group` is kept
      #   as an alias for backwards compatibility.
      class Base
        attr_reader :id, :name, :group
        attr_writer :consumer

        # Backwards compatible alias for `#group`. Kept purely for compatibility - this is an
        # unconditional alias and performs no type validation, so callers should prefer `#group`.
        alias_method :consumer_group, :group

        attr_accessor :subscription_group_details

        # Full subscription group reference can be built only when we have knowledge about the
        # whole routing tree, this is why it is going to be set later on
        attr_accessor :subscription_group

        # Attributes we can inherit from the root unless they were defined on this level
        INHERITABLE_ATTRIBUTES = %i[
          kafka
          max_messages
          max_wait_time
          initial_offset
          consumer_persistence
        ].freeze

        private_constant :INHERITABLE_ATTRIBUTES

        # @param name [String, Symbol] name of a topic on which we want to listen
        # @param group [Karafka::Routing::Groups::Base] owning group of this topic
        def initialize(name, group)
          @name = name.to_s
          @group = group
          @attributes = {}
          @active = true
          # We use identifier related to the group that owns a topic, because from Karafka 0.6 we can
          # handle multiple Kafka instances with the same process and we can have same topic name
          # across multiple groups
          @id = "#{group.id}_#{@name}"
          @consumer = nil
          @active_assigned = false
          @subscription_group_details = nil

          INHERITABLE_ATTRIBUTES.each do |attribute|
            instance_variable_set("@#{attribute}", nil)
          end

          # Explicit nil initialization for Ruby's object shapes optimization. The per-topic pause
          # config is built lazily on first read, defaulting to the global `config.pause.*` settings.
          @pause = nil
        end

        INHERITABLE_ATTRIBUTES.each do |attribute|
          # Defined below
          attr_writer attribute unless attribute == :kafka

          class_eval <<~RUBY, __FILE__, __LINE__ + 1
            def #{attribute}
              return @#{attribute} unless @#{attribute}.nil?

              @#{attribute} = Karafka::App.config.send(:#{attribute})
            end
          RUBY
        end

        # @return [Symbol] the type of the owning group (`:consumer` / `:share`)
        def group_type
          group.group_type
        end

        # @return [Karafka::Routing::Features::Pausing::Config] per-topic pause configuration,
        #   reflecting the root `config.pause.*` settings.
        def pause
          @pause ||= Features::Pausing::Config.new(
            active: false,
            timeout: Karafka::App.config.pause.timeout,
            max_timeout: Karafka::App.config.pause.max_timeout,
            with_exponential_backoff: Karafka::App.config.pause.with_exponential_backoff
          )
        end

        # Often users want to have the same basic cluster setup with small setting alterations
        # This method allows us to do so by setting `inherit` to `true`. Whe inherit is enabled,
        # settings will be merged with defaults.
        #
        # @param settings [Hash] kafka scope settings. If `:inherit` key is provided, it will
        #   instruct the assignment to merge with root level defaults
        #
        # @note It is set to `false` by default to preserve backwards compatibility
        def kafka=(settings = {})
          inherit = settings.delete(:inherit)

          @kafka = inherit ? Karafka::App.config.kafka.merge(settings) : settings
        end

        # @return [String] name of subscription that will go to librdkafka
        def subscription_name
          name
        end

        # @return [Class, String] consumer class or its stringified version if it was defined
        #   using a string
        def consumer
          # If consumer is a string, we need to constantize it as it was provided as a string to
          # allow for the code reload for anonymous consumer classes, but this is an edge case
          if @consumer.is_a?(String)
            begin
              Object.const_get(@consumer.to_s)
            rescue NameError
              # It will only fail if the in case of anonymous classes
              @consumer
            end
          else
            @consumer
          end
        end

        # Allows to disable topic by invoking this method and setting it to `false`.
        # @param active [Boolean] should this topic be consumed or not
        def active(active)
          # Do not allow for active overrides. Basically if this is set on the topic level, defaults
          # will not overwrite it and this is desired. Otherwise because of the fact that this is
          # not a full feature config but just a flag, default value would always overwrite the
          # per-topic config since defaults application happens after the topic config block
          unless @active_assigned
            @active = active
            @active_assigned = true
          end

          @active
        end

        # @return [Class] consumer class that we should use
        # @note This is just an alias to the `#consumer` method. We however want to use it internally
        #   instead of referencing the `#consumer`. We use this to indicate that this method returns
        #   class and not an instance. In the routing we want to keep the `#consumer Consumer`
        #   routing syntax, but for references outside, we should use this one.
        def consumer_class
          consumer
        end

        # @return [Boolean] should this topic be in use
        def active?
          # Never active if disabled via routing
          return false unless @active

          Karafka::App.config.internal.routing.activity_manager.active?(:topics, name)
        end

        # @return [Hash] hash with all the topic attributes
        # @note This is being used when we validate the group and its topics
        def to_h
          map = INHERITABLE_ATTRIBUTES.map do |attribute|
            [attribute, public_send(attribute)]
          end

          map.to_h.merge!(
            id: id,
            name: name,
            active: active?,
            consumer: consumer,
            pause: pause.to_h,
            group_id: group.id,
            # Kept as a reference alongside `group_id` for backwards compatibility. Will be removed
            # in Karafka 3.0.
            consumer_group_id: group.id,
            subscription_group_details: subscription_group_details
          ).freeze
        end
      end
    end
  end
end
