# frozen_string_literal: true

ENV['BUNDLE_GEMFILE'] = '../Gemfile'
ENV['KARAFKA_ENV'] = 'test'

require 'benchmark/ips'
require_relative '../lib/karafka'

Benchmark.ips do |x|
  x.config(warmup: 0, time: 15)

  hash = {
    'key' => :value,
    'payload' => '{ "key": "value" }',
    'deserializer' => Karafka::Serialization::Json::Deserializer.new
  }
  params = Karafka::Params::Params.new.merge!(hash)

  x.report("'Hash#['key']'") do
    hash['key']
  end

  x.report("Params#['key']") do
    params['key']
  end

  x.report("Params#['payload']") do
    params['payload']
  end

  x.report('Params#payload') do
    params.payload
  end

  x.compare!
end
