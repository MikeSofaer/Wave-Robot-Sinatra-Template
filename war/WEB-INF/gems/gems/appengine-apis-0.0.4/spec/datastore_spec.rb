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
require 'appengine-apis/datastore'

describe AppEngine::Datastore do
  Datastore = AppEngine::Datastore
  
  before :each do
    AppEngine::Testing.install_test_datastore
  end
  
  it "should support get/put" do
    entity = Datastore::Entity.new("Test")
    entity[:a] = "a"
    entity[:b] = "b"
    key = Datastore.put(entity)
    entity.key.should == key
    stored = Datastore.get(key)
    stored.should == entity
    stored[:a].should == "a"
    stored[:b].should == "b"
  end
  
  it "should support Text" do
    entity = Datastore::Entity.new("Test")
    entity[:a] = Datastore::Text.new("a")
    Datastore.put(entity)
    stored = Datastore.get(entity.key)
    stored[:a].should be_a(Datastore::Text)
    stored[:a].should == "a"
    stored.to_hash['a'].should == "a"
  end
  
  it "should put many" do
    a = Datastore::Entity.new("A")
    b = Datastore::Entity.new("B")
    keys = Datastore.put(a, b)
    keys.size.should == 2
    keys[0].kind.should == "A"
    keys[1].kind.should == "B"
    got = Datastore.get(keys)
    got.size.should == 2
    got[0].should == a
    got[1].should == b
  end

  it "should support failed transactions" do
    pending("Real local transactions") do
      a = Datastore::Entity.new("A")
      a[:a] = 0
      Datastore.put(a)
      p = lambda do
        Datastore.transaction do
          a2 = Datastore.get(a.key)
          a[:a] += 1
          Datastore.put(nil, a)
          Datastore.put(a2)
        end
      end
      p.should raise_error Datastore::TransactionFailed
    end
  end

  it "should retry transactions" do
    pending("Real local transactions") do
      a = Datastore::Entity.new("A")
      a[:a] = 0
      Datastore.put(a)
      Datastore.transaction(3) do
        a2 = Datastore.get(a.key)
        a[:a] += 1
        Datastore.put(nil, a) if a[:a] < 3
        a2[:a] = "2: #{a2[:a]}"
        Datastore.put(a2)
      end
  
      Datastore.get(a.key)[:a].should == '2: 2'
    end
  end
  
  it "should close transactions" do
    lambda {Datastore.transaction{ raise "Foo"}}.should raise_error "Foo"
    Datastore.active_transactions.to_a.should == []
  end
end

describe AppEngine::Datastore::Query do
  Datastore = AppEngine::Datastore
  Query = AppEngine::Datastore::Query
  
  before :all do
    AppEngine::Testing.install_test_datastore
    @a = Datastore::Entity.new("A")
    @a['name'] = 'a'
    Datastore.put(@a)
    
    @aa = Datastore::Entity.new("A", @a.key)
    @aa['name'] = 'aa'
    
    @b = Datastore::Entity.new("B")
    @b['name'] = 'b'
    
    @ab = Datastore::Entity.new("B", @a.key)
    @ab['name'] = 'ab'
    Datastore.put(@aa, @ab, @b)
  end

  it "should support chaining" do
    q = Query.new("Foo")
    q.set_ancestor(@a.key).sort('name').filter(
        'name', Query::EQUAL, 'Bob').should == q
  end
  
  it 'should support symbol ops' do
    q = Query.new("Foo")
    q.set_ancestor(@a.key).sort('name').filter(
        'name', :==, 'aa')
    q.fetch.to_a.should == [@aa]
  end
  
  it "should support ancestor" do
    a = @a.key
    q = Query.new("A", a)
    q.java_query.ancestor.should == a
    q.fetch.to_a.should == [@a, @aa]
    
    q = Query.new("A")
    q.set_ancestor(a)
    q.java_query.ancestor.should == a
    q.fetch.to_a.should == [@a, @aa]
    
    q = Query.new("A")
    q.ancestor = a
    q.java_query.ancestor.should == a
    q.fetch.to_a.should == [@a, @aa]
  end
  
  it "should support ancestor only" do
    a = @a.key
    q = Query.new(a)
    q.java_query.ancestor.should == a
    pending("Local ancestory only queries") do
      q.fetch.to_a.should == [@a, @aa, @ab]
    end
  end
  
  it "should support sort" do
    q = Query.new("A")
    q.sort('name', Query::DESCENDING)
    q.fetch.to_a.should == [@aa, @a]
  end

end
