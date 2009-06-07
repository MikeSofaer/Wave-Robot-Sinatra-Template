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
#
# The Ruby datastore API used by app developers.
#
# Defines the Query class, as well as methods for all of the
# datastore's calls. Also defines conversions between the Ruby classes and
# their Java counterparts.
#
# The datastore errors are defined in datastore_types.rb.

require 'appengine-apis/datastore_types'

module AppEngine
  
# The Datastore provides access to a schema-less data
# storage system.  The fundamental unit of data in this system is the
# Datastore::Entity, which has an immutable identity (represented by a
# Datastore::Key) and zero of more mutable properties.  Entity
# objects can be created, updated, deleted, retrieved by identifier,
# and queried via a combination of properties using Datastore::Query.
#
# The +Datastore+ can be used transactionally and supports the
# notion of a "current" transaction.  A current transaction is established by
# calling #begin_transaction.  The transaction returned by this method
# ceases to be current when an attempt is made to commit or rollback or when
# another call is made to #begin_transaction.  A transaction can only
# be current within the +Thread+ that created it.
#
# The various overloads of put, get, and delete all support transactions.
# Users of this class have the choice of explicitly passing a (potentially
# null) +Transaction+ to these methods or relying on the current transaction.
#
# Supported property types:
# - String (max 500 chars)
# - Integer ((-2**63)..(2**63 - 1))
# - Float
# - Time
# - TrueClass
# - FalseClass
# - NilClass
# - Datastore::Key
# - Datastore::Link
# - Datastore::Text
# - Datastore::Blob
# - Datastore::ByteString
# - Users::User

module Datastore
  module_function
  
  # call-seq:
  #   Datastore.get(transaction=current_transaction, key) -> Entity
  #   Datastore.get(transaction=current_transaction, [keys]) -> Entities
  #
  # Retrieves one or more entities from the datastore.
  #
  # Retrieves the entity or entities with the given key(s) from the datastore
  # and returns them as fully populated Entity objects, as defined below. If
  # there is an error, raises a subclass of Datastore::Error.
  #
  # With a single key, an Entity will be returned, or
  # EntityNotFound will be raised if no existing entity matches the key.
  #
  # With an array of keys, an array of entities will be returned that
  # corresponds to the sequence of keys. It will include entities for keys
  # that were found and None placeholders for keys that were not found.
  #
  # If transaction is specified, it will be used instead of the
  # current transaction.
  #
  def get(*args)
    convert_exceptions do
      args = extract_tx(args)
      entities = @@db.get(*args)
      if entities.kind_of? java.util.Map
        keys = args[-1]
        entities = keys.collect do |key|
          entities.get(key)
        end
      end
      entities
    end
  end
  
  # call-seq:
  #   Datastore.put(transaction=current_transaction, entity) -> Key
  #   Datastore.put(transaction=current_transaction, entities) -> Keys
  #
  # Store one or more entities in the datastore.
  # 
  # The entities may be new or previously existing. For new entities, #put will
  # fill in the app id and key assigned by the datastore.
  # 
  # If the argument is a single Entity, a single Key will be returned. If the
  # argument is an array of Entity, an Enumerable of Keys will be returned.
  #
  # If transaction is specified this operation will execute within that
  # transaction instead of the current transaction.
  #
  def put(*args)
    convert_exceptions do
      args = extract_tx(args)
      @@db.put(*args)
    end
  end
  
  # call-seq:
  #   Datastore.delete(transaction=current_transaction, key)
  #   Datastore.delete(transaction=current_transaction, [keys])
  #
  # Deletes one or more entities from the datastore.
  #
  # If transaction is specified this operation will execute within that
  # transaction instead of the current transaction.
  #
  def delete(*args)
    convert_exceptions do
      args = extract_tx(args)
      @@db.delete(*args)
    end
  end
  
  # Begins a transaction agains the datastore. Callers are
  # responsible for explicitly calling #Transaction.commit or 
  # #Transaction.rollback when they no longer need the Transaction.
  #
  # The Transaction returned by this call will be considered the
  # current transaction and will be returned by subsequent, same-thread
  # calls to #current_transaction until one of the following happens:
  #
  # 1. begin_transaction is invoked from the same thread. In this case
  #    current_transaction will return the result of the more recent
  #    call to begin_transaction.
  # 2. Transaction.commit is invoked on the Transaction returned by
  #    this method.  Whether or not the commit succeeds, the
  #    Transaction will no longer be current.
  # 3. Transaction.rollback is invoked on the Transaction returned by
  #    this method.  Whether or not the rollback succeeds, the
  #    Transaction will no longer be current.
  #
  def begin_transaction
    convert_exceptions do
      @@db.begin_transaction
    end
  end
  
  # call-seq:
  #   Datastore.current_transaction -> transaction || IndexError
  #   Datastore.current_transaction(default) -> transaction
  #
  # Returns the current transaction for this thread. The current transaction
  # is defined as the result of the most recent, same-thread invocation of
  # #begin_transaction that has not been committed or rolled back.
  #
  # Raises IndexError if there is no current transaction and no default
  # is specified.
  #
  def current_transaction(*args)
    convert_exceptions do
      @@db.current_transaction(*args)
    end
  end
  
  # Returns all Transactions started by this thread upon which no
  # attempt to commit or rollback has been made.
  #
  def active_transactions
    convert_exceptions do
      @@db.active_transactions
    end
  end
  
  # Runs the block inside a transaction. Every #get, #put, and #delete
  # call in the block is made within the transaction, unless another
  # transaction is explicitly specified.
  #
  # The block may raise any exception to roll back the transaction instead of
  # committing it. If this happens, the transaction will be rolled back and the
  # exception will be re-raised up to #transaction's caller.
  # 
  # If you want to roll back intentionally, but don't have an appropriate
  # exception to raise, you can raise an instance of Datastore::Rollback.
  # It will cause a rollback, but will *not* be re-raised up to the caller.
  # 
  # If retries is greater than 0 and the transaction fails to commit,
  # the block may be run more than once, so it should be idempotent. It
  # should avoid side effects, and it shouldn't have *any* side effects that
  # aren't safe to occur multiple times. However, this doesn't
  # include Put, Get, and Delete calls, of course.
  #
  def transaction(retries=3)
    while retries >= 0
      retries -= 1
      tx = begin_transaction
      begin
        result = yield
        tx.commit
        return result
      rescue Rollback
        tx.rollback
        return nil
      rescue TransactionFailed
        raise ex unless retries >= 0
      ensure
        begin
          tx.rollback
        rescue java.lang.IllegalStateException
          # already commited/rolled back. ignore
        rescue java.util.NoSuchElementException
          # already commited/rolled back. ignore
        end
      end
    end
    raise TransactionFailed
  end
  
  def extract_tx(args)  # :nodoc:
    tx = :none
    keys = args[0]
    if keys.java_kind_of?(JavaDatastore::Transaction) || keys.nil?
      tx = args.shift
      keys = args[0]
    end
    if args.size > 1
      keys = args
    end
    if keys.kind_of? Array
      keys = Iterable.new(keys)
    end
    if tx == :none
      [keys]
    else
      [tx, keys]
    end
  end
  
  def service  # :nodoc:
    @@db
  end
  
  # Query encapsulates a request for zero or more
  # Entity objects out of the datastore.  It supports querying on
  # zero or more properties, querying by ancestor, and sorting.  
  # Entity objects which match the query can be retrieved in a single
  # list, or with an unbounded iterator.
  #
  # A Query does not cache results. Each use of the Query results in a new
  # trip to the Datastore.
  #
  class Query
    JQuery = JavaDatastore::Query
    FetchOptions = JavaDatastore::FetchOptions
    
    module Constants
      EQUAL = JQuery::FilterOperator::EQUAL
      GREATER_THAN = JQuery::FilterOperator::GREATER_THAN
      GREATER_THAN_OR_EQUAL = JQuery::FilterOperator::GREATER_THAN_OR_EQUAL
      LESS_THAN = JQuery::FilterOperator::LESS_THAN
      LESS_THAN_OR_EQUAL = JQuery::FilterOperator::LESS_THAN_OR_EQUAL
      
      ASCENDING = JQuery::SortDirection::ASCENDING
      DESCENDING = JQuery::SortDirection::DESCENDING
      
      OP_MAP = Hash.new { |hash, key| key }
      OP_MAP.update('==' => EQUAL, '>' => GREATER_THAN,
                    '>=' => GREATER_THAN_OR_EQUAL, '<' => LESS_THAN,
                    '<=' => LESS_THAN_OR_EQUAL)
      OP_MAP.freeze
    end
    include Constants
    
    # call-seq:
    #   Query.new(kind)
    #   Query.new(ancestor)
    #   Query.new(kind, ancestor)
    #
    # Creates a new Query with the specified kind and/or ancestor.
    # 
    # Args:
    # - kind: String. Only return entities with this kind.
    # - ancestor: Key. Only return entities with the given ancestor.
    #
    def initialize(*args)
      @query = JQuery.new(*args)
    end
    
    def kind
      @query.kind
    end
    
    
    def ancestor
      @query.ancestor
    end
    
    # Sets an ancestor for this query.
    #
    # This restricts the query to only return result entities that are
    # descended from a given entity. In other words, all of the results
    # will have the ancestor as their parent, or parent's parent, or
    # etc.
    #
    # If nil is specified, unsets any previously-set ancestor.
    #
    # Throws ArgumentError if the ancestor key is incomplete, or if
    # you try to unset an ancestor and have not set a kind.
    #
    def ancestor=(key)
      Datastore.convert_exceptions do
        @query.set_ancestor(key)
      end
      clear_cache
    end

    # call-seq:
    #   query.set_ancestor(key) -> query
    #
    # Sets an ancestor for this query.
    #
    # This restricts the query to only return result entities that are
    # descended from a given entity. In other words, all of the results
    # will have the ancestor as their parent, or parent's parent, or
    # etc.
    #
    # If nil is specified, unsets any previously-set ancestor.
    #
    # Throws ArgumentError if the ancestor key is incomplete, or if
    # you try to unset an ancestor and have not set a kind.
    #
    def set_ancestor(key)
      self.ancestor = key
      self
    end
    
    # Add a filter on the specified property.
    #
    # Note that entities with multi-value properties identified by name
    # will match this filter if the multi-value property has at least one
    # value that matches the condition expressed by +operator+ and
    # +value+.  For more information on multi-value property filtering
    # please see the {datastore 
    # documentation}[http://code.google.com/appengine/docs/java/datastore]
    #
    def filter(name, operator, value)
      name = name.to_s if name.kind_of? Symbol
      operator = operator.to_s if operator.kind_of? Symbol
      operator = OP_MAP[operator]
      value = Datastore.ruby_to_java(value)
      @query.add_filter(name, operator, value)
      clear_cache
    end
    
    # Specify how the query results should be sorted.
    #
    # The first call to #sort will register the property that will
    # serve as the primary sort key.  A second call to #sort will set
    # a secondary sort key, etc.
    #
    # This method will sort in ascending order by defaul. To control the
    # order of the sort, pass ASCENDING or DESCENDING as the direction.
    #
    # Note that entities with multi-value properties identified by
    # name will be sorted by the smallest value in the list.
    # For more information on sorting properties with multiple values please see
    # the {datastore 
    # documentation}[http://code.google.com/appengine/docs/java/datastore].
    #
    # Returns self (for chaining)
    #
    def sort(name, direction=ASCENDING)
      name = name.to_s if name.kind_of? Symbol
      @query.add_sort(name, direction)
      clear_cache
    end
    
    # Returns an unmodifiable list of the current filter predicates.
    def filter_predicates
      @query.getFilterPredicates
    end
    
    # Returns an unmodifiable list of the current sort predicates.
    def sort_predicates
      @query.getSortPredicates
    end
    
    # Returns the number of entities that currently match this query.
    def count
      pquery.count
    end
    
    # Retrieves the one and only result for the {@code Query}.
    # 
    # Throws TooManyResults if more than one result is returned
    # from the Query.
    # 
    # Returns the single, matching result, or nil if no entities match
    #
    def entity
      Datastore.convert_exceptions do
        pquery.as_single_entity
      end
    end
    
  
    # Streams the matching entities from the datastore and yields each
    # matching entity.
    #
    # See #convert_options for supported options
    def each(options={}, &proc)  # :yields: entity
      options = convert_options(options)
      Datastore.convert_exceptions do
        pquery.as_iterator(options).each(&proc)
      end
    end
    
    # Returns an Enumerable over the matching entities.
    #
    # See #convert_options for supported options
    #
    def iterator(options={})
      options = convert_options(options)
      Datastore.convert_exceptions do
        pquery.as_iterator(options)
      end
    end

    # Fetch all matching entities. For large result sets you should
    # prefer #each or #iterator, which stream the results from the
    # datastore.
    #
    def fetch(options={})
      options = convert_options(options)
      Datastore.convert_exceptions do
        pquery.as_list(options)
      end      
    end

    # Returns a Java.ComGoogleAppengineApiDatastore.PreparedQuery
    # for this query.
    #
    def pquery
      @pquery ||= Datastore.service.prepare(@query)
    end
    
    # Returns a Java.ComGoogleAppengineApiDatastore.Query for this query.
    def java_query
      @query
    end
    
    # Converts an options hash into FetchOptions.
    #
    # Supported options:
    # [:limit] Maximum number of results the query will return
    # [:offset]
    #     Number of result to skip before returning any
    #     results.  Results that are skipped due to offset do not count
    #     against +limit+.
    # [:chunk]
    #     Determines the internal chunking strategy of the iterator
    #     returned by #iterator. This affects only the performance of
    #     the query, not the actual results returned.
    #
    def convert_options(options)
      return options if options.java_kind_of? FetchOptions
      limit = options.delete(:limit)
      offset = options.delete(:offset)
      chunk_size = options.delete(:chunk) || FetchOptions::DEFAULT_CHUNK_SIZE
      unless options.empty?
        raise ArgumentError, "Unsupported options #{options.inspect}"
      end
      options = FetchOptions::Builder.with_chunk_size(chunk_size)
      options.offset(offset) if offset
      options.limit(limit) if limit
      options
    end
    
    private
    def clear_cache
      @pquery = nil
      self
    end
  end
  
  class Iterable  # :nodoc:
    include java.lang.Iterable
    def initialize(array)
      @array = array
    end
    
    def iterator
      Iterator.new(@array)
    end
  end
  
  class Iterator  # :nodoc:
    include java.util.Iterator
    def initialize(array)
      @array = array
      @index = 0
      @removed = false
    end
    
    def hasNext
      @index < @array.size
    end
    
    def next
      raise java.util.NoSuchElementException unless hasNext
      @removed = false
      @index += 1
      @array[@index - 1]
    end
    
    def remove
      raise java.lang.IllegalStateException if @removed
      raise java.lang.IllegalStateException unless @index > 0
      @removed = true
      @array.delete_at(@index - 1)
    end
  end
  
  @@db ||= JavaDatastore::DatastoreServiceFactory.getDatastoreService
end
end