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
require 'appengine-apis/memcache'

describe AppEngine::Memcache do
  before :each do
    AppEngine::Testing::install_test_datastore
    @cache = AppEngine::Memcache.new
  end
  
  before :all do
    AppEngine::Testing::install_test_env
  end
  
  describe 'get' do
    
    it 'should return nil on miss' do
      @cache.get('foobar').should == nil
      @cache['foobar'].should == nil
    end
    
    it 'should support strings' do
      @cache.set('foobar', 'test').should == true
      @cache.get('foobar').should == 'test'
      @cache['foobar'].should == 'test'
    end
    
    it 'should support multiple values' do
      @cache.get('foo', 'bar', 'baz').should == [nil, nil, nil]
      @cache['foo', 'bar', 'baz'].should == [nil, nil, nil]
      @cache.set('bar', 'food').should == true
      @cache['foo', 'bar', 'baz'].should == [nil, 'food', nil]
    end
    
    it 'should support getting an array of keys' do
      @cache.set('foobar', 'test').should == true
      @cache.get(['foobar', 'flowers']).should == ['test', nil]
      @cache.get(['foobar']).should == ['test']
    end
    
    it 'should support numbers' do
      @cache.set('one', 1).should == true
      @cache.set('pi', 3.14).should == true
      @cache.get('pi').should == 3.14
      @cache.get('one').should === 1
    end
    
    it 'should support symbol keys' do
      @cache.set(:a, 'A')
      @cache.get(:a).should == 'A'
    end
    
    it 'should support booleans' do
      @cache.set('true', true)
      @cache.set('false', false)
      @cache.get('true').should == true
      @cache.get('false').should == false
    end
    
    it 'should support marshaled objects' do
      @cache.set('a', 1..5)
      @cache.get('a').should == (1..5)
    end
    
    it 'should support false keys' do
      @cache.set(nil, 'nil')
      @cache.set(false, 'false')
      @cache.get(nil).should == 'nil'
      @cache.get(false).should == 'false'
    end
  end
  
  describe 'get_hash' do
    it 'should not include missing keys' do
      @cache.get_hash(:a, :b).should == {}
    end
    
    it 'should get objects' do
      @cache.set('a', 'A')
      @cache.set('b', 3)
      @cache.get_hash('a', 'c', 'b').should == {'a' => 'A', 'b' => 3 }
    end
  end
  
  describe 'clear' do
    it 'should clear the cache' do
      @cache.set(:a, 'A')
      @cache.set('b', 'B')
      @cache.clear
      @cache.get_hash(:a, 'b', :c).should == {}
    end
  end
  
  describe 'flush_all' do
    it 'should clear the cache' do
      @cache.set(:a, 'A')
      @cache.set('b', 'B')
      @cache.flush_all
      @cache.get_hash(:a, 'b', :c).should == {}
    end
  end
  
  describe 'stats' do
    it 'should count items' do
      @cache.stats[:items].should == 0
      @cache.set(:a, 'A')
      @cache.stats[:items].should == 1
    end
  end

  describe 'delete' do
    it 'should remove items' do
      @cache.set(:a, 'A')
      @cache.get(:a).should == 'A'
      @cache.delete(:a).should == true
      @cache.get(:a).should == nil
      @cache.get_hash(:a).should == {}
    end
    
    it 'should return false on missing items' do
      @cache.delete(:a).should == false
    end
    
    it 'should allow blocking adds' do
      @cache.set(:a, '1')
      @cache.set(:b, '2')
      @cache.delete(:a)
      @cache.delete(:b, 1)
      @cache.add(:a, 'A').should == true
      @cache.add(:b, 'B').should == false
    end
  end
  
  describe 'delete_many' do
    it 'should remove items' do
      @cache.set(:a, 'A')
      @cache.set(:b, 'B')
      @cache.set(:c, 'C')
      @cache.delete_many([:a, :c])
      @cache.get_hash(:a, :b, :c).should == {:b => 'B'}
    end
    
    it 'should return removed keys' do
      @cache.set('a', 'A')
      @cache.set('b', 'B')
      @cache.set('c', 'C')
      removed = @cache.delete_many(['a', 'c'])
      removed.sort.should == ['a', 'c']
    end
    
    it 'should not return missing keys' do
      @cache.set('a', 'A')
      @cache.set('b', 'B')
      @cache.set('c', 'C')
      removed = @cache.delete_many(['a', 'c', 'd', 'e'])
      removed.sort.should == ['a', 'c']
      @cache.delete_many(['e']).should == []
    end
    
    
    it 'should allow blocking adds' do
      @cache.set(:a, '1')
      @cache.set(:b, '2')
      @cache.delete_many([:a])
      @cache.delete([:b, :c], 1)
      @cache.add(:a, 'A').should == true
      @cache.add(:b, 'B').should == false
    end
  end
  
  describe 'add' do
    it 'should add missing' do
      @cache.add(:a, 'A').should == true
      @cache.get(:a).should == 'A'
    end
    
    it 'should not replace existing entries' do
      @cache.set(:a, 1)
      @cache.add(:a, 'A').should == false
      @cache.get(:a).should == 1
    end
  end
  
  describe 'add_many' do
    it 'should add missing' do
      @cache.add_many({:a => 1, :b =>2})
      @cache.get(:b, :a).should == [2, 1]
    end
    
    it 'should not replace existing entries' do
      @cache.set(:a, 1)
      @cache.add_many({:a => 'A', :b => 'B'})
      @cache.get(:a, :b).should == [1, 'B']
    end
    
    it 'should return existing keys' do
      @cache.set(:a, 1)
      @cache.add_many({:a => 'A', :b => 'B'}).should == [:a]
    end
  end
  
  describe 'set' do
    it 'should add missing' do
      @cache.set(:a, :A).should == true
      @cache.get(:a).should == :A
    end
    
    it 'should replace existing' do
      @cache.set(:a, :A).should == true
      @cache.get(:a).should == :A
      @cache.set(:a, 1).should == true
      @cache.get(:a).should == 1
    end
  end
  
  describe 'set_many' do
    it 'should set multiple values' do
      @cache.set_many({:a => 1, :b => 2}).should == []
    end
  end
  
  describe 'replace' do
    it 'should replace existing' do
      @cache.set(:a, :A).should == true
      @cache.get(:a).should == :A
      @cache.replace(:a, 1).should == true
      @cache.get(:a).should == 1
    end
    
    it 'should not replace missing' do
      @cache.replace(:a, :A).should == false
    end
  end
  
  describe 'replace_many' do
    it 'should replace many' do
      @cache.set_many({:a => 1, :c => 3})
      @cache.replace_many({:a => :A, :b => :B, :c => :C}).should == [:b]
      @cache.get(:a, :b, :c).should == [:A, nil, :C]
    end
  end
  
  describe 'dict access' do
    it 'should support getting with []' do
      @cache.set(:a, 7)
      @cache[:a].should == 7
      @cache.set(:b, :B)
      @cache[:a, :b].should == [7, :B]
    end
    
    it 'should support setting with []=' do
      @cache[:a, :b] = [1, :B]
      @cache[:c] = 3
      @cache[:a].should == 1
      @cache[:b].should == :B
      @cache[:c].should == 3
    end
  end
  
  describe 'incr' do
    it 'should increment number' do
      @cache.set(:a, 1)
      @cache.incr(:a).should == 2
      @cache.incr(:a, 7).should == 9
      @cache.get(:a).should == 9
    end
    
    it 'should wrap' do
      @cache.set(:a, 7)
      @cache.incr(:a, 2**62).should == 2**62 + 7
      @cache.incr(:a, 2**62).should < 2**62
    end
    
    it 'should fail if not number' do
      @cache.incr(:a).should == nil
      @cache.get_hash([:a]).should == {}
      @cache.set(:b, :foo)
      lambda {@cache.incr(:b)}.should raise_error(
          AppEngine::Memcache::InvalidValueError)
    end
    
    it 'should increment strings' do
      @cache.set(:a, '7')
      @cache.incr(:a).should == 8
    end
  end
  
  describe 'decr' do
    it 'should decrement number' do
      @cache.set(:a, 7)
      @cache.decr(:a).should == 6
      @cache.get(:a).should == 6
      @cache.decr(:a, 2).should == 4
      @cache.get(:a).should == 4
      @cache.decr(:a, 4).should == 0
      @cache.get(:a).should == 0
      pending 'local decrement wrapping' do
        @cache.decr(:a, 6).should == 0
        @cache.get(:a).should == 0
      end
    end
  end
  
  describe 'readonly' do
    before :each do
      @rocache = AppEngine::Memcache.new(:readonly => true)
      @ex = AppEngine::Memcache::MemcacheError
    end
    
    it 'should allow reads' do
      @cache[:a] = 1
      @rocache.get(:a).should == 1
    end
    
    it 'should allow stats' do
      @cache[:a] = 7
      @rocache.stats[:items].should == 1
    end
    
    it 'should block delete' do
      @cache[:a] = 1
      lambda {@rocache.delete(:a)}.should raise_error(@ex)
      @cache[:a].should == 1
    end
    
    it 'should block add' do
      lambda {@rocache.add(:a, 1)}.should raise_error(@ex)
      lambda {@rocache.add_many({:b => 1})}.should raise_error(@ex)
      @rocache.get_hash(:a, :b).should == {}
    end
    
    it 'should block set' do
      lambda {@rocache.set(:a, 1)}.should raise_error(@ex)
      lambda {@rocache.set_many({:b => 1})}.should raise_error(@ex)
      @rocache.get_hash(:a, :b).should == {}
    end
    
    it 'should block replace' do
      @cache[:a, :b] = :A, :B
      lambda {@rocache.replace(:a, 1)}.should raise_error(@ex)
      lambda {@rocache.replace_many({:b => 1})}.should raise_error(@ex)
      @rocache[:a, :b].should == [:A, :B]
    end
    
    it 'should block clear' do
      @cache[:a] = 1
      lambda {@rocache.clear}.should raise_error(@ex)
      lambda {@rocache.flush_all}.should raise_error(@ex)
      @rocache[:a].should == 1
    end
    
    it 'should block incr' do
      @cache[:a] = 1
      lambda {@rocache.incr(:a)}.should raise_error(@ex)
      @rocache[:a].should == 1
    end
    
    it 'should block decr' do
      @cache[:a] = 1
      lambda {@rocache.decr(:a)}.should raise_error(@ex)
      @rocache[:a].should == 1
    end
  end
  
  describe "namespaces" do
    it 'should get namespace from initialize' do
      cache = AppEngine::Memcache.new(:namespace => "foo")
      cache.namespace.should == "foo"
    end
  end
end
