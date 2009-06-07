#!/usr/bin/ruby1.8 -w
#
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
#

require 'appengine-apis/datastore_types'

module AppEngine
  
  # The Ruby API for the App Engine Memcache service. This offers a fast
  # distrubted cache for commonly-used data. The cache is limited both in
  # duration and also in total space, so objects stored in it may be discarded
  # at any time.
  # 
  # Note that null is a legal value to store in the cache, or to use as a cache
  # key. Strings are stored encoded as utf-8. To store binary data use
  # AppEngine::Datastore::Blob or +str.to_java_bytes+.
  # 
  # The values returned from this API are mutable copies from the cache;
  # altering them has no effect upon the cached value itself until assigned
  # with one of the put methods. Likewise, the methods returning collections
  # return mutable collections, but changes do not affect the cache.
  # 
  # Except for the #incr and #decr methods, this service does not offer
  # atomicity guarantees. In particular, operations accessing multiple
  # keys are non-atomic.
  #
  # Increment has a number of caveats to its use; please consult the method
  # documentation.
  class Memcache
    import com.google.appengine.api.memcache.Expiration
    import com.google.appengine.api.memcache.InvalidValueException
    import com.google.appengine.api.memcache.LogAndContinueErrorHandler
    import com.google.appengine.api.memcache.MemcacheServiceException
    import com.google.appengine.api.memcache.MemcacheServiceFactory
    import com.google.appengine.api.memcache.MemcacheService
    import com.google.appengine.api.memcache.StrictErrorHandler
    
    ADD = MemcacheService::SetPolicy::ADD_ONLY_IF_NOT_PRESENT
    REPLACE = MemcacheService::SetPolicy::REPLACE_ONLY_IF_PRESENT
    SET = MemcacheService::SetPolicy::SET_ALWAYS
    
    # Base Memcache exception class
    class MemcacheError < StandardError; end
    
    MemCacheError = MemcacheError
    ClientError = MemcacheError
    InternalError = MemcacheError
    
    MARSHAL_MARKER = '--JRuby Marshal Data--'
    
    # An exception for backend non-availability or similar error states which
    # may occur, but are not necessarily indicative of a coding or usage error
    # by the application.
    class ServerError < MemcacheError; end
    
    # Raised when a cache entry has content, but it cannot be read. For example:
    # - An attempt to #incr a non-integral value
    # - Version skew between your application and the data in the cache,
    #   causing a marshaling error.
    class InvalidValueError < MemcacheError; end
    
    def initialize(*servers)
      options = if servers[-1].kind_of? Hash
        servers[-1]
      else
        {}
      end
      if options.include?(:namespace)
        service.namespace = options[:namespace]
      end
      @readonly = options[:readonly]
    end

    # Returns the Java MemcacheService object used by this Memcache client.
    def service
      @service ||= MemcacheServiceFactory.memcache_service
    end
    
    def active?
      # TODO use the capability api to see if Memcache is disabled.
      true
    end
    
    # Empties the cache of all values. Statistics are not affected. Note that
    # #clear does not respect namespaces - this flushes the cache for every
    # namespace.
    #
    # Returns true on success, false on RPC or server error.
    def flush_all
      check_write
      with_errors do
        begin
          service.clear_all
          return true
        rescue MemcacheError
          return false
        end
      end
    end
    alias clear flush_all
    
    # Gets memcache statistics for this application.
    # 
    # All of these statistics may reset due to various transient conditions.
    # They provide the best information available at the time of being called.
    #
    # Returns a Hash mapping statistic names to associated values:
    # [:hits] Number of cache get requests resulting in a cache hit.
    # [:misses] Number of cache get requests resulting in a cache miss.
    # [:byte_hits] Sum of bytes transferred on get requests. Rolls over to
    #              zero on overflow.
    # [:items] Number of key/value pairs in the cache.
    # [:bytes] Total size of all items in the cache.
    # [:oldest_item_age]
    #   How long in seconds since the oldest item in the
    #   cache was accessed. Effectively, this indicates how long a new
    #   item will survive in the cache without being accessed. This is
    #   _not_ the amount of time that has elapsed since the item was
    #   created.
    #
    # On error, returns +nil+.
    def stats
      with_errors do
        begin
          stats = service.statistics
          if stats
            {
              :hits => stats.hit_count,
              :misses => stats.miss_count,
              :byte_hits => stats.bytes_returned_for_hits,
              :items => stats.item_count,
              :bytes => stats.total_item_bytes,
              :oldest_item_age => stats.max_time_without_access / 1000.0
            }
          end
        rescue ServerError
          nil
        end
      end
    end
    
    # Fetch and return the values associated with the given +key+s from the
    # cache. Returns +nil+ for any value that wasn’t in the cache.
    def get(*keys)
      multiple = (keys.size != 1)
      if !multiple && keys[0].kind_of?(Array)
        keys = keys[0]
        multiple = true
      end
      hash = get_hash(*keys)
      values = keys.collect {|key| hash[key]}
      if multiple
        values
      else
        values[0]
      end
    end
    alias [] get
    
    # Looks up multiple keys from memcache in one operation. This is more
    # efficient than multiple separate calls to #get.
    # 
    # Args:
    # - keys: List of keys to look up.
    # 
    # Returns a hash of the keys and values that were present in memcache.
    def get_hash(*keys)
      key_map = KeyMap.new(keys)
      convert_exceptions do
        map = service.getAll(key_map.java_keys)
        key_map.map_to_hash(map) do |value|
          if value.java_kind_of?(java.util.ArrayList) && value.size == 2 &&
              value[0] == MARSHAL_MARKER
            Marshal.load(String.from_java_bytes(value[1]))
          else
            value
          end
        end
      end
    end
    
    # Removes the given key from the cache, and prevents it from being added
    # using #add for +time+ seconds thereafter. Calls to #set are not blocked.
    #
    # Returns true if an entry existed to delete.
    def delete(key, time=nil)
      time ||= 0
      check_write
      convert_exceptions do
        service.delete(memcache_key(key), time * 1000)
      end
    end

    # Removes the given keys from the cache, and prevents them from being added
    # using #add for +time+ seconds thereafter. Calls to #set are not blocked.
    #
    # Returns the set of keys deleted. Any keys in +keys+ but not in the
    # returned set were not found in the cache.
    def delete_many(keys, time=0)
      check_write
      key_map = KeyMap.new(keys)
      convert_exceptions do
        java_keys = service.delete_all(key_map.java_keys, time * 1000)
        key_map.ruby_keys(java_keys)
      end      
    end
    
    # Sets a key's value, iff item is not already in memcache.
    # 
    # Args:
    # - key: Key to set.
    # - value: Value to set.  Any type.  If complex, will be marshaled.
    # - expiration: Optional expiration time, either relative number of seconds
    #   from current time (up to 1 month), an absolute Unix epoch time, or a
    #   Time. By default, items never expire, though items may be evicted due
    #   to memory pressure.
    # 
    # Returns true if added, false on error.
    def add(key, value, expiration=0)
      put(key, value, expiration, ADD)
    end
    
    # Set multiple keys' values iff items are not already in memcache.
    # 
    # Args:
    # - pairs: Hash of keys to values, or Array of [key, value] pairs.
    # - expiration: Optional expiration time, either relative number of seconds
    #   from current time (up to 1 month), an absolute Unix epoch time, or a
    #   Time. By default, items never expire, though items may be evicted due
    #   to memory pressure.
    # 
    # Returns a list of keys whose values were NOT set.  On total success
    # this list should be empty.
    def add_many(pairs, expiration=0)
      put_many(pairs, expiration, ADD)
    end
    
    # Sets a key's value, regardless of previous contents in cache.
    # 
    # Unlike #add and #replace, this method always sets (or
    # overwrites) the value in memcache, regardless of previous
    # contents.
    # 
    # Args:
    # - key: Key to set.
    # - value: Value to set.  Any type.  If complex, will be marshaled.
    # - expiration: Optional expiration time, either relative number of seconds
    #   from current time (up to 1 month), an absolute Unix epoch time, or a
    #   Time. By default, items never expire, though items may be evicted due
    #   to memory pressure.
    # 
    # Returns true if set, false on error.
    def set(key, value, expiration=0)
      put(key, value, expiration, SET)
    end
    
    # Set multiple keys' values at once, regardless of previous contents.
    # 
    # Args:
    # - pairs: Hash of keys to values, or Array of [key, value] pairs.
    # - expiration: Optional expiration time, either relative number of seconds
    #   from current time (up to 1 month), an absolute Unix epoch time, or a
    #   Time. By default, items never expire, though items may be evicted due
    #   to memory pressure.
    # 
    # Returns a list of keys whose values were NOT set.  On total success
    # this list should be empty.
    def set_many(pairs, expiration=0)
      put_many(pairs, expiration, SET)
    end
    
    # call-seq:
    #   cache[:foo, :bar] = 1, 2
    #
    # Syntactic sugar for calling set_many.
    def []=(*args)
      values = args.pop
      if values.kind_of? Array
        set_many(args.zip(values))
      else
        set(args, values)
      end
    end
    
    # Replaces a key's value, failing if item isn't already in memcache.
    # 
    # Unlike #add and #replace, this method always sets (or
    # overwrites) the value in memcache, regardless of previous
    # contents.
    # 
    # Args:
    # - key: Key to set.
    # - value: Value to set.  Any type.  If complex, will be marshaled.
    # - expiration: Optional expiration time, either relative number of seconds
    #   from current time (up to 1 month), an absolute Unix epoch time, or a
    #   Time. By default, items never expire, though items may be evicted due
    #   to memory pressure.
    # 
    # Returns true if replaced, false on cache miss.
    def replace(key, value, expiration=0)
      put(key, value, expiration, REPLACE)
    end
    
    # Replace multiple keys' values, failing if the items aren't in memcache.
    # 
    # Args:
    # - pairs: Hash of keys to values, or Array of [key, value] pairs.
    # - expiration: Optional expiration time, either relative number of seconds
    #   from current time (up to 1 month), an absolute Unix epoch time, or a
    #   Time. By default, items never expire, though items may be evicted due
    #   to memory pressure.
    # 
    # Returns a list of keys whose values were NOT set.  On total success
    # this list should be empty.
    def replace_many(pairs, expiration=0)
      put_many(pairs, expiration, REPLACE)
    end
    
    # Atomically fetches, increments, and stores a given integral value.
    # "Integral" types are Fixnum and in some cases String (if the string is
    # parseable as a number. The entry must already exist.
    #
    # Internally, the value is a unsigned 64-bit integer.  Memcache
    # doesn't check 64-bit overflows.  The value, if too large, will
    # wrap around.
    #
    # Args:
    # - key: the key of the entry to manipulate
    # - delta: the size of the increment.
    #
    # Returns the post-increment value.
    #
    # Throws InvalidValueError if the object incremented is not of
    # an integral type.
    def incr(key, delta=1)
      check_write
      convert_exceptions do
        service.increment(memcache_key(key), delta)
      end
    end

    # Atomically fetches, deccrements, and stores a given integral value.
    # "Integral" types are Fixnum and in some cases String (if the string is
    # parseable as a number. The entry must already exist.
    #
    # Internally, the value is a unsigned 64-bit integer.  Memcache
    # caps decrementing below zero to zero.
    #
    # Args:
    # - key: the key of the entry to manipulate
    # - delta: the size of the decrement
    #
    # Returns the post-decrement value.
    #
    # Throws InvalidValueError if the object decremented is not of
    # an integral type.
    def decr(key, delta=1)
      check_write
      convert_exceptions do
        service.increment(memcache_key(key), -delta)
      end
    end
    
    # Get the name of the namespace that will be used in API calls.
    def namespace
      service.namespace
    end
    
    # Change the namespace used in API calls.
    def namespace=(value)
      service.namespace = value
    end
    
    # Returns true if the cache was created read-only.
    def readonly?
      @readonly
    end
    
    def inspect
      "<Memcache ns:#{namespace.inspect}, ro:#{readonly?.inspect}>"
    end
    
    # Returns whether the client raises an exception if there's an error
    # contacting the server. By default it will simulate a cache miss
    # instead of raising an error.
    def raise_errors?
      service.error_handler.kind_of? StrictErrorHandler
    end
    
    # Set whether this client raises an exception if there's an error
    # contacting the server.
    #
    # If +should_raise+ is true, a ServerError is raised whenever there
    # is an error contacting the server.
    #
    # If +should_raise+ is false (the default), a cache miss is simulated
    # instead of raising an error.
    def raise_errors=(should_raise)
      if should_raise
        service.error_handler = StrictErrorHandler.new
      else
        service.error_handler = LogAndContinueErrorHandler.new
      end
    end
    
    # For backwards compatibility. Simply returns nil
    def do_nothing(*args)
    end
    alias server_item_stats do_nothing
    alias server_malloc_stats do_nothing
    alias server_map_stats do_nothing
    alias server_reset_stats do_nothing
    alias server_size_stats do_nothing
    alias server_slab_stats do_nothing
    alias server_stats do_nothing
    alias servers= do_nothing
    
    private
    
    def memcache_key(obj)
      key = obj
      key = key.to_s.to_java_string if key
      key
    end

    def memcache_value(obj)
      case obj
      when Fixnum
        java.lang.Long.new(obj)
      when Float
        java.lang.Double.new(obj)
      when TrueClass, FalseClass
        java.lang.Boolean.new(obj)
      when JavaProxy, Java::JavaObject
        obj
      else
        if obj.class == String
          # Convert plain strings to Java strings
          obj.to_java_string
        else
          bytes = Marshal.dump(obj).to_java_bytes
          java.util.ArrayList.new([MARSHAL_MARKER.to_java_string, bytes])
        end
      end
    end
    
    def memcache_expiration(amount)
      if amount.nil? || amount == 0
        nil
      elsif amount.kind_of? Time
        Expiration.on_date(amount.to_java)
      elsif amount > 86400 * 30
        millis = (amount * 1000).to_i
        Expiration.on_date(java.util.Date.new(millis))
      else
        Expiration.byDeltaMillis((amount * 1000).to_i)
      end
    end
    
    def check_write
      raise MemcacheError, "readonly cache" if self.readonly?
    end

    def with_errors(&block)
      saved_handler = service.error_handler
      begin
        service.error_handler = StrictErrorHandler.new
        convert_exceptions(&block)
      ensure
        service.error_handler = saved_handler
      end
    end
    
    def convert_exceptions
      begin
        yield
      rescue java.lang.IllegalArgumentException => ex
        raise ArgumentError, ex.message
      rescue InvalidValueException => ex
        raise InvalidValueError, ex.message
      rescue MemcacheServiceException => ex
        raise ServerError, ex.message
      end
    end
    
    def put(key, value, expiration, mode)
      check_write
      convert_exceptions do
        key = memcache_key(key)
        value = memcache_value(value)
        expiriation = memcache_expiration(expiriation)
        service.put(key, value, expiriation, mode)
      end
    end
    
    def put_many(pairs, expiration, mode)
      check_write
      expiration = memcache_expiration(expiration)
      convert_exceptions do
        key_map = KeyMap.new
        put_map = java.util.HashMap.new
        pairs.each do |key, value|
          java_key = key_map << key
          java_value = memcache_value(value)
          put_map.put(java_key, java_value)
        end
        saved_keys = service.put_all(put_map, expiration, mode)
        key_map.missing_keys(saved_keys)
      end
    end
    
    class KeyMap  # :nodoc:
      def initialize(keys=[])
        @orig_keys = []
        @map = {}
        keys.each do |key|
          self << key
        end
      end
      
      def <<(key)
        @orig_keys << key
        string_key = if key
          key.to_s
        else
          key
        end
        @map[string_key] = key
        if string_key
          string_key.to_java_string
        else
          string_key
        end
      end
      
      def java_keys
        @map.keys.collect do |key|
          if key
            key.to_java_string
          else
            key
          end
        end
      end
      
      def ruby_keys(keys)
        keys.collect {|key| @map[key]}
      end
      
      def missing_keys(keys)
        @orig_keys - ruby_keys(keys)
      end
      
      def map_to_hash(java_map)
        hash = {}
        if java_map
          java_map.each do |key, value|
            value = yield(value)
            hash[@map[key]] = value
          end
        end
        hash
      end
    end
  end
end