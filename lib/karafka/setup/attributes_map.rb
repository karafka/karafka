# frozen_string_literal: true

module Karafka
  module Setup
    # To simplify the overall design, in Karafka we define all the rdkafka settings in one scope
    # under `kafka`. rdkafka though does not like when producer options are passed to the
    # consumer configuration and issues warnings. This target map is used as a filtering layer, so
    # only appropriate settings go to both producer and consumer
    #
    # It is built based on https://github.com/edenhill/librdkafka/blob/master/CONFIGURATION.md
    module AttributesMap
      # List of rdkafka consumer accepted attributes
      CONSUMER = %i[
        allow.auto.create.topics
        api.version.fallback.ms
        api.version.request
        api.version.request.timeout.ms
        auto.commit.enable
        auto.commit.interval.ms
        auto.offset.reset
        background_event_cb
        bootstrap.servers
        broker.address.family
        broker.address.ttl
        broker.version.fallback
        builtin.features
        check.crcs
        client.dns.lookup
        client.id
        client.rack
        closesocket_cb
        connect_cb
        connections.max.idle.ms
        consume.callback.max.messages
        consume_cb
        coordinator.query.interval.ms
        debug
        default_topic_conf
        enable.auto.commit
        enable.auto.offset.store
        enable.metrics.push
        enable.partition.eof
        enable.random.seed
        enable.sasl.oauthbearer.unsecure.jwt
        enable.ssl.certificate.verification
        enabled_events
        error_cb
        fetch.error.backoff.ms
        fetch.max.bytes
        fetch.message.max.bytes
        fetch.min.bytes
        fetch.queue.backoff.ms
        fetch.wait.max.ms
        group.id
        group.instance.id
        group.protocol
        group.protocol.type
        group.remote.assignor
        heartbeat.interval.ms
        interceptors
        internal.termination.signal
        isolation.level
        log.connection.close
        log.queue
        log.thread.name
        log_cb
        log_level
        max.in.flight
        max.in.flight.requests.per.connection
        max.partition.fetch.bytes
        max.poll.interval.ms
        message.copy.max.bytes
        message.max.bytes
        metadata.broker.list
        metadata.max.age.ms
        metadata.recovery.strategy
        oauthbearer_token_refresh_cb
        offset.store.method
        offset.store.path
        offset.store.sync.interval.ms
        offset_commit_cb
        opaque
        open_cb
        partition.assignment.strategy
        plugin.library.paths
        queued.max.messages.kbytes
        queued.min.messages
        rebalance_cb
        receive.message.max.bytes
        reconnect.backoff.jitter.ms
        reconnect.backoff.max.ms
        reconnect.backoff.ms
        resolve_cb
        retry.backoff.max.ms
        retry.backoff.ms
        sasl.kerberos.keytab
        sasl.kerberos.kinit.cmd
        sasl.kerberos.min.time.before.relogin
        sasl.kerberos.principal
        sasl.kerberos.service.name
        sasl.mechanism
        sasl.mechanisms
        sasl.oauthbearer.client.id
        sasl.oauthbearer.client.secret
        sasl.oauthbearer.config
        sasl.oauthbearer.extensions
        sasl.oauthbearer.method
        sasl.oauthbearer.scope
        sasl.oauthbearer.token.endpoint.url
        sasl.password
        sasl.username
        security.protocol
        session.timeout.ms
        socket.blocking.max.ms
        socket.connection.setup.timeout.ms
        socket.keepalive.enable
        socket.max.fails
        socket.nagle.disable
        socket.receive.buffer.bytes
        socket.send.buffer.bytes
        socket.timeout.ms
        socket_cb
        ssl.ca.certificate.stores
        ssl.ca.location
        ssl.ca.pem
        ssl.certificate.location
        ssl.certificate.pem
        ssl.certificate.verify_cb
        ssl.cipher.suites
        ssl.crl.location
        ssl.curves.list
        ssl.endpoint.identification.algorithm
        ssl.engine.id
        ssl.engine.location
        ssl.key.location
        ssl.key.password
        ssl.key.pem
        ssl.keystore.location
        ssl.keystore.password
        ssl.providers
        ssl.sigalgs.list
        ssl_ca
        ssl_certificate
        ssl_engine_callback_data
        ssl_key
        statistics.interval.ms
        stats_cb
        throttle_cb
        topic.blacklist
        topic.metadata.propagation.max.ms
        topic.metadata.refresh.fast.cnt
        topic.metadata.refresh.fast.interval.ms
        topic.metadata.refresh.interval.ms
        topic.metadata.refresh.sparse
      ].freeze

      # List of rdkafka producer accepted attributes
      PRODUCER = %i[
        acks
        allow.auto.create.topics
        api.version.fallback.ms
        api.version.request
        api.version.request.timeout.ms
        background_event_cb
        batch.num.messages
        batch.size
        bootstrap.servers
        broker.address.family
        broker.address.ttl
        broker.version.fallback
        builtin.features
        client.dns.lookup
        client.id
        client.rack
        closesocket_cb
        compression.codec
        compression.level
        compression.type
        connect_cb
        connections.max.idle.ms
        debug
        default_topic_conf
        delivery.report.only.error
        delivery.timeout.ms
        dr_cb
        dr_msg_cb
        enable.gapless.guarantee
        enable.idempotence
        enable.metrics.push
        enable.random.seed
        enable.sasl.oauthbearer.unsecure.jwt
        enable.ssl.certificate.verification
        enabled_events
        error_cb
        interceptors
        internal.termination.signal
        linger.ms
        log.connection.close
        log.queue
        log.thread.name
        log_cb
        log_level
        max.in.flight
        max.in.flight.requests.per.connection
        message.copy.max.bytes
        message.max.bytes
        message.send.max.retries
        message.timeout.ms
        metadata.broker.list
        metadata.max.age.ms
        metadata.recovery.strategy
        msg_order_cmp
        oauthbearer_token_refresh_cb
        opaque
        open_cb
        partitioner
        partitioner_cb
        plugin.library.paths
        produce.offset.report
        queue.buffering.backpressure.threshold
        queue.buffering.max.kbytes
        queue.buffering.max.messages
        queue.buffering.max.ms
        queuing.strategy
        receive.message.max.bytes
        reconnect.backoff.jitter.ms
        reconnect.backoff.max.ms
        reconnect.backoff.ms
        request.required.acks
        request.timeout.ms
        resolve_cb
        retries
        retry.backoff.max.ms
        retry.backoff.ms
        sasl.kerberos.keytab
        sasl.kerberos.kinit.cmd
        sasl.kerberos.min.time.before.relogin
        sasl.kerberos.principal
        sasl.kerberos.service.name
        sasl.mechanism
        sasl.mechanisms
        sasl.oauthbearer.client.id
        sasl.oauthbearer.client.secret
        sasl.oauthbearer.config
        sasl.oauthbearer.extensions
        sasl.oauthbearer.method
        sasl.oauthbearer.scope
        sasl.oauthbearer.token.endpoint.url
        sasl.password
        sasl.username
        security.protocol
        socket.blocking.max.ms
        socket.connection.setup.timeout.ms
        socket.keepalive.enable
        socket.max.fails
        socket.nagle.disable
        socket.receive.buffer.bytes
        socket.send.buffer.bytes
        socket.timeout.ms
        socket_cb
        ssl.ca.certificate.stores
        ssl.ca.location
        ssl.ca.pem
        ssl.certificate.location
        ssl.certificate.pem
        ssl.certificate.verify_cb
        ssl.cipher.suites
        ssl.crl.location
        ssl.curves.list
        ssl.endpoint.identification.algorithm
        ssl.engine.id
        ssl.engine.location
        ssl.key.location
        ssl.key.password
        ssl.key.pem
        ssl.keystore.location
        ssl.keystore.password
        ssl.providers
        ssl.sigalgs.list
        ssl_ca
        ssl_certificate
        ssl_engine_callback_data
        ssl_key
        statistics.interval.ms
        stats_cb
        sticky.partitioning.linger.ms
        throttle_cb
        topic.blacklist
        topic.metadata.propagation.max.ms
        topic.metadata.refresh.fast.cnt
        topic.metadata.refresh.fast.interval.ms
        topic.metadata.refresh.interval.ms
        topic.metadata.refresh.sparse
        transaction.timeout.ms
        transactional.id
      ].freeze

      # Location of the file with rdkafka settings list
      SOURCE = <<~SOURCE.delete("\n").gsub(/\s+/, '/')
        https://raw.githubusercontent.com
          confluentinc/librdkafka
          v#{Rdkafka::LIBRDKAFKA_VERSION}
          CONFIGURATION.md
      SOURCE

      private_constant :SOURCE

      class << self
        # Filter the provided settings leaving only the once applicable to the consumer
        # @param kafka_settings [Hash] all kafka settings
        # @return [Hash] settings applicable to the consumer
        def consumer(kafka_settings)
          kafka_settings.slice(*CONSUMER)
        end

        # Filter the provided settings leaving only the once applicable to the producer
        # @param kafka_settings [Hash] all kafka settings
        # @return [Hash] settings applicable to the producer
        def producer(kafka_settings)
          kafka_settings.slice(*PRODUCER)
        end

        # @private
        # @return [Hash<Symbol, Array<Symbol>>] hash with consumer and producer attributes list
        #   that is sorted.
        # @note This method should not be used directly. It is only used to generate appropriate
        #   options list in case it would change
        def generate
          # Not used anywhere else, hence required here
          require 'open-uri'

          attributes = { consumer: Set.new, producer: Set.new }

          ::URI.parse(SOURCE).open.readlines.each do |line|
            next unless line.include?('|')

            attribute, attribute_type = line.split('|').map(&:strip)

            case attribute_type
            when 'C'
              attributes[:consumer] << attribute
            when 'P'
              attributes[:producer] << attribute
            when '*'
              attributes[:consumer] << attribute
              attributes[:producer] << attribute
            else
              next
            end
          end

          attributes.transform_values!(&:sort)
          attributes.each_value { |vals| vals.map!(&:to_sym) }
          attributes
        end
      end
    end
  end
end
