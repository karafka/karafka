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
      # Attributes accepted by every rdkafka client type (network, security, socket, metadata,
      # etc.). Shared by consumer groups, share groups and the producer, so they are defined once
      # here and merged into each scope below.
      COMMON = %i[
        allow.auto.create.topics
        api.version.fallback.ms
        api.version.request
        api.version.request.timeout.ms
        background_event_cb
        bootstrap.servers
        broker.address.family
        broker.address.ttl
        broker.version.fallback
        builtin.features
        client.dns.lookup
        client.id
        client.rack
        closesocket_cb
        connect_cb
        connections.max.idle.ms
        debug
        default_topic_conf
        enable.metrics.push
        enable.random.seed
        enable.sasl.oauthbearer.unsecure.jwt
        enable.ssl.certificate.verification
        enabled_events
        error_cb
        https.ca.location
        https.ca.pem
        interceptors
        internal.termination.signal
        log.connection.close
        log.queue
        log.thread.name
        log_cb
        log_level
        max.in.flight
        max.in.flight.requests.per.connection
        message.max.bytes
        metadata.broker.list
        metadata.max.age.ms
        metadata.recovery.rebootstrap.trigger.ms
        metadata.recovery.strategy
        oauthbearer_token_refresh_cb
        opaque
        open_cb
        plugin.library.paths
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
        sasl.oauthbearer.assertion.algorithm
        sasl.oauthbearer.assertion.claim.aud
        sasl.oauthbearer.assertion.claim.exp.seconds
        sasl.oauthbearer.assertion.claim.iss
        sasl.oauthbearer.assertion.claim.jti.include
        sasl.oauthbearer.assertion.claim.nbf.seconds
        sasl.oauthbearer.assertion.claim.sub
        sasl.oauthbearer.assertion.file
        sasl.oauthbearer.assertion.jwt.template.file
        sasl.oauthbearer.assertion.private.key.file
        sasl.oauthbearer.assertion.private.key.passphrase
        sasl.oauthbearer.assertion.private.key.pem
        sasl.oauthbearer.client.credentials.client.id
        sasl.oauthbearer.client.credentials.client.secret
        sasl.oauthbearer.client.id
        sasl.oauthbearer.client.secret
        sasl.oauthbearer.config
        sasl.oauthbearer.extensions
        sasl.oauthbearer.grant.type
        sasl.oauthbearer.metadata.authentication.type
        sasl.oauthbearer.method
        sasl.oauthbearer.scope
        sasl.oauthbearer.sub.claim.name
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
        throttle_cb
        topic.metadata.propagation.max.ms
        topic.metadata.refresh.fast.cnt
        topic.metadata.refresh.fast.interval.ms
        topic.metadata.refresh.interval.ms
        topic.metadata.refresh.sparse
      ].freeze

      # Attributes shared by both consumer variants (regular consumer-group consumers and KIP-932
      # share consumers) on top of {COMMON} - the "it is a consumer" basics: fetch sizing, group
      # membership, session/heartbeat and offset store.
      CONSUMER_COMMON = %i[
        check.crcs
        consume.callback.max.messages
        coordinator.query.interval.ms
        fetch.max.bytes
        fetch.message.max.bytes
        fetch.min.bytes
        fetch.wait.max.ms
        group.id
        group.protocol
        group.protocol.type
        heartbeat.interval.ms
        max.partition.fetch.bytes
        max.poll.interval.ms
        offset.store.method
        offset.store.path
        offset.store.sync.interval.ms
        session.timeout.ms
      ].freeze

      # Consumer-group only attributes on top of {COMMON} + {CONSUMER_COMMON}: offset commits and
      # resets, client-side assignment, static group membership and other regular-consumer only
      # properties that do not apply to share consumers.
      CONSUMER_GROUP_SPECIFIC = %i[
        auto.commit.enable
        auto.commit.interval.ms
        auto.offset.reset
        consume_cb
        enable.auto.commit
        enable.auto.offset.store
        enable.partition.eof
        fetch.error.backoff.ms
        fetch.queue.backoff.ms
        group.instance.id
        group.remote.assignor
        isolation.level
        message.copy.max.bytes
        offset_commit_cb
        partition.assignment.strategy
        queued.max.messages.kbytes
        queued.min.messages
        rebalance_cb
        topic.blacklist
      ].freeze

      # Share consumer (KIP-932) only attributes on top of {COMMON} + {CONSUMER_COMMON}. Curated
      # from the librdkafka 2.15.0 preview CONFIGURATION.md share-consumer notes.
      SHARE_GROUP_SPECIFIC = %i[
        max.poll.records
        share.acknowledgement.mode
      ].freeze

      # Producer only attributes on top of {COMMON}.
      PRODUCER_SPECIFIC = %i[
        acks
        batch.num.messages
        batch.size
        compression.codec
        compression.level
        compression.type
        delivery.report.only.error
        delivery.timeout.ms
        dr_cb
        dr_msg_cb
        enable.gapless.guarantee
        enable.idempotence
        linger.ms
        message.copy.max.bytes
        message.send.max.retries
        message.timeout.ms
        msg_order_cmp
        partitioner
        partitioner_cb
        produce.offset.report
        queue.buffering.backpressure.threshold
        queue.buffering.max.kbytes
        queue.buffering.max.messages
        queue.buffering.max.ms
        queuing.strategy
        request.required.acks
        request.timeout.ms
        retries
        sticky.partitioning.linger.ms
        topic.blacklist
        transaction.timeout.ms
        transactional.id
      ].freeze

      # List of rdkafka consumer-group (regular) consumer accepted attributes
      CONSUMER_GROUP = (COMMON + CONSUMER_COMMON + CONSUMER_GROUP_SPECIFIC).sort.freeze

      # List of rdkafka share consumer (KIP-932) accepted attributes
      SHARE_GROUP = (COMMON + CONSUMER_COMMON + SHARE_GROUP_SPECIFIC).sort.freeze

      # List of rdkafka producer accepted attributes
      PRODUCER = (COMMON + PRODUCER_SPECIFIC).sort.freeze

      # Location of the file with rdkafka settings list
      SOURCE = <<~SOURCE.delete("\n").gsub(/\s+/, "/")
        https://raw.githubusercontent.com
          confluentinc/librdkafka
          v#{Rdkafka::LIBRDKAFKA_VERSION}
          CONFIGURATION.md
      SOURCE

      private_constant :SOURCE

      class << self
        # Filter the provided settings leaving only the ones applicable to a consumer-group
        # (regular) consumer
        # @param kafka_settings [Hash] all kafka settings
        # @return [Hash] settings applicable to the consumer-group consumer
        def consumer_group(kafka_settings)
          kafka_settings.slice(*CONSUMER_GROUP)
        end

        # Legacy alias for {.consumer_group}. Kept for backwards compatibility.
        alias_method :consumer, :consumer_group

        # Filter the provided settings leaving only the ones applicable to a KIP-932 share
        # consumer
        # @param kafka_settings [Hash] all kafka settings
        # @return [Hash] settings applicable to the share consumer
        def share_group(kafka_settings)
          kafka_settings.slice(*SHARE_GROUP)
        end

        # Filter the provided settings leaving only the once applicable to the producer
        # @param kafka_settings [Hash] all kafka settings
        # @return [Hash] settings applicable to the producer
        def producer(kafka_settings)
          kafka_settings.slice(*PRODUCER)
        end

        # @private
        # @return [Hash{Symbol => Array<Symbol>}] hash with consumer and producer attributes list
        #   that is sorted.
        # @note This method should not be used directly. It is only used to generate appropriate
        #   options list in case it would change
        def generate
          # Not used anywhere else, hence required here
          require "open-uri"

          attributes = { consumer: Set.new, producer: Set.new }

          URI.parse(SOURCE).open.readlines.each do |line|
            next unless line.include?("|")

            attribute, attribute_type = line.split("|").map(&:strip)

            case attribute_type
            when "C"
              attributes[:consumer] << attribute
            when "P"
              attributes[:producer] << attribute
            when "*"
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
