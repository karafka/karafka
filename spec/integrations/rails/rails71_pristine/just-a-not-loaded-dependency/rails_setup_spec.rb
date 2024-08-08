# frozen_string_literal: true

# Karafka should work without Rails even when Rails is in the Gemfile as long as the
# KARAFKA_REQUIRE_RAILS is set to `"false"`

ENV['KARAFKA_CLI'] = 'true'
ENV['KARAFKA_REQUIRE_RAILS'] = 'false'

Bundler.require(:default)

Bundler.require(:default)

ENV['KARAFKA_BOOT_FILE'] = 'false'

assert !Karafka.rails?
