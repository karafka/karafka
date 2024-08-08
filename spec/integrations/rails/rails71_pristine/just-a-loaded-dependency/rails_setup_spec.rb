# frozen_string_literal: true

# Karafka should be default require Rails when `KARAFKA_REQUIRE_RAILS` is not set to `"false"`

ENV['KARAFKA_CLI'] = 'true'

Bundler.require(:default)

Bundler.require(:default)

ENV['KARAFKA_BOOT_FILE'] = 'false'

assert Karafka.rails?
