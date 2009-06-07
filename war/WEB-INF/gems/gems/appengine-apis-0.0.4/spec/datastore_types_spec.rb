# Copyright:: Copyright 2009 Google Inc.
# Original Author:: Ryan Brown (mailto:ribrdb@google.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require File.dirname(__FILE__) + '/spec_helper.rb'
require 'appengine-apis/datastore_types'

describe AppEngine::Datastore::Key do
  Key = AppEngine::Datastore::Key
  
  it "should support ==" do
    a1 = Key.from_path("A", 1)
    a2 = Key.from_path("A", 1)
    a1.should == a2
    a2.should.eql? a1
    a1.hash.should == a2.hash
    pending("Key.compareTo") do
      (a1 <=> a2).should == 0
    end
  end

  it "should support <=>" do
    pending("Key.compareTo") do
      a1 = Key.from_path("A", 1)
      a2 = Key.from_path("A", 2)
      a1.should < a2
      a2.should > a1
      (a1 <=> a2).should == -1
      (a2 <=> a1).should == 1
    end
  end
  
  it "should create from id" do
    key = Key.from_path("Foo", 27)
    key.kind.should == 'Foo'
    key.id.should == 27
    key.id_or_name.should == 27
  end
  
  it "should create from name" do
    key = Key.from_path("Bar", 'baz')
    key.kind.should == 'Bar'
    key.name.should == 'baz'
    key.id_or_name.should == 'baz'
  end
  
  it "should create with parent" do
    parent = Key.from_path("Foo", 1)
    key = Key.from_path(parent, "Bar", 2)
    key.kind.should == 'Bar'
    key.id.should == 2
    key.parent.should == parent
  end
  
  it "should support long paths" do
    key = Key.from_path('A', 1, 'B', 2, 'C', 3)
    key.kind.should == 'C'
    key.id.should == 3
    key.parent.kind.should == 'B'
    key.parent.id.should == 2
    key.parent.parent.kind.should == 'A'
    key.parent.parent.id.should == 1
  end
  
  it "should encode" do
    key = Key.from_path('Foo', 'bar')
    key.to_s.should == 'agR0ZXN0cgwLEgNGb28iA2Jhcgw'
  end
  
  it "should create from encoded" do
    decoded = Key.new('agR0ZXN0cgwLEgNGb28iA2Jhcgw')
    key = Key.from_path('Foo', 'bar')
    decoded.should == key
  end
  
end

describe AppEngine::Datastore::Entity do

  before :each do
    @entity = AppEngine::Datastore::Entity.new('Test')
  end
  
  it "should support nil" do
    @entity['nil'] = nil
    @entity.has_property?('nil').should == true
    @entity['nil'].should == nil
  end
  
  it "should support true" do
    @entity['true'] = true
    @entity['true'].should == true
  end
  
  it "should support false" do
    @entity['false'] = false
    @entity['false'].should == false
  end
    
  it "should support Strings" do
    @entity['string'] = 'a string'
    @entity['string'].should == 'a string'
  end
  
  it "should support Integers" do
    @entity['int'] = 42
    @entity['int'].should == 42
  end
  
  it "should support Floats" do
    @entity['float'] = 3.1415
    @entity['float'].should == 3.1415
  end
  
  it "should support Symbol for name" do
    @entity[:foo] = 'bar'
    @entity[:foo].should == 'bar'
    @entity['foo'].should == 'bar'
  end
  
  it "should support Text" do
    text = 'Some text. ' * 1000
    @entity['text'] = AppEngine::Datastore::Text.new(text)
    @entity['text'].should == text
    @entity['text'].class.should == AppEngine::Datastore::Text
  end
  
  it "should support Blob" do
    blob = "\0\1\2" * 1000
    @entity['blob'] = AppEngine::Datastore::Blob.new(blob)
    @entity['blob'].should == blob
    @entity['blob'].class.should == AppEngine::Datastore::Blob
  end
  
  it "should support ByteString" do
    blob = "\0\1\2"
    @entity['blob'] = AppEngine::Datastore::ByteString.new(blob)
    @entity['blob'].should == blob
    @entity['blob'].class.should == AppEngine::Datastore::ByteString
  end
  
  it "should support Link" do
    link = "http://example.com/" + "0" * 1000
    @entity['link'] = AppEngine::Datastore::Link.new(link)
    @entity['link'].should == link
    @entity['link'].class.should == AppEngine::Datastore::Link
  end
  
  it "should support Time" do
    time = Time.now - 3600
    @entity['time'] = time
    @entity['time'].to_s.should == time.to_s
    @entity['time'].class.should == Time
  end
  
  it "should support multiple values" do
    list = [1, 2, 3]
    @entity['list'] = list
    @entity['list'].should == list
  end
  
  it "should not support random types" do
      lambda{@entity['foo'] = Kernel}.should raise_error(ArgumentError)
  end
  
  it "should support delete" do
    @entity['foo'] = 'bar'
    @entity.delete('foo')
    @entity.has_property?('foo').should == false
  end
    
  it "should support delete symbol" do
    @entity['foo'] = 'bar'
    @entity.delete(:foo)
    @entity.has_property?('foo').should == false
  end
  
  it "should support each" do
    props = {'foo' => 'bar', 'count' => 3}
    props.each {|name, value| @entity[name] = value}
    @entity.each do |name, value|
      props.delete(name).should == value
    end
    props.should == {}
  end
  
  it "should support update" do
    @entity.update('foo' => 'bar', 'count' => 3)
    @entity[:foo].should == 'bar'
    @entity[:count].should == 3
  end
  
  it "should support to_hash" do
    props = {'foo' => 'bar', 'count' => 3}
    @entity.merge!(props)
    @entity.to_hash.should == props
  end
end

describe AppEngine::Datastore::Text do
  it "should support to_s" do
    t = AppEngine::Datastore::Text.new("foo")
    t.to_s.should == t
  end
end

