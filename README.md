## CRITICAL NOTICE ON KARAFKA 1.4 reliability

You are looking at the `1.4` version of Karafka that is no longer supported.

Karafka `1.4` is no longer supported and contains critical errors, included but not limited to:

  - Double processing of messages
  - Skipping messages
  - Hanging during processing
  - Unexpectedly stopping message processing
  - Failure to deliver messages to Kafka
  - Resetting the consumer group and starting from the beginning

To resolve these issues, it is highly recommended to upgrade to Karafka 2.1 or higher.

If you want to ignore this message and continue, set the I_ACCEPT_CRITICAL_ERRORS_IN_KARAFKA_1_4 env variable to true.

Apologies for any inconvenience caused by this release.
There is no other way to make sure, that you are notified about those issues and their severity.

If you need help with the upgrade, we do have a Slack channel you can join: https://slack.karafka.io/
