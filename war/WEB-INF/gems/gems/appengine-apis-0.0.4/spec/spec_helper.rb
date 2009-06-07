begin
  require 'spec'
rescue LoadError
  require 'rubygems'
  gem 'rspec'
  require 'spec'
end

$:.unshift(File.dirname(__FILE__) + '/../lib')
require 'appengine-apis/testing'
AppEngine::Testing.install_test_env

class ProtoMatcher
  def compare(hash, proto, prefix='')
    hash.each do |key, value|
      name = "#{prefix}#{key}"
      case value
      when Array
        if value[0].kind_of? Hash
          count = proto.send("#{key}_size")
          compare_value("#{name}.size", value.size, count)
          value.each_with_index do |item, index|
            break if index == count
            compare(item, proto.send(key, index), "#{name}[#{index}].")
          end
        else
          actual = proto.send("#{key}s").to_a
          compare_value(name, value, actual)
        end
      when Hash
        compare(value, proto.send(key), "#{name}.")
      else
        compare_value(name, value, proto.send(key))
      end
    end
  end
  
  def compare_value(label, expected, actual)
    if expected != actual
      @failures << "%s differs. expected: %s actual: %s" % 
          [label, expected.inspect, actual.inspect]
    end
  end
  
  def initialize(klass, expected)
    @klass = klass
    @expected = expected
  end
  
  def matches(bytes)
    @failures = []
    @proto = @klass.new
    @proto.parse_from(bytes)
    compare(@expected, @proto)
    @failures.empty?
  end
  
  def ==(bytes)
    Spec::Expectations.fail_with(failure_message) unless matches(bytes)
    true
  end
  
  def failure_message
    @failures.join("\n")
  end
end

module ProtoMethods
  def proto(klass, hash)
    ProtoMatcher.new(klass, hash)
  end
  alias be_proto proto
  
  def mock_delegate
    delegate = mock("apiproxy")
    delegate.instance_eval do
      class << self
        include AppEngine::ApiProxy::Delegate
      end
    end
  end  
end

Spec::Runner.configure do |config|
  config.include(ProtoMethods)
end