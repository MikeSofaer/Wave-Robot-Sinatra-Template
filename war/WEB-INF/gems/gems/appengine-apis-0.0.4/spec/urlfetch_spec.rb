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


require File.dirname(__FILE__) + '/spec_helper.rb'
require 'appengine-apis/urlfetch'
require 'uri'

module AppEngine::URLFetch
  class FakeResponse
    def initialize(status, body, headers)
      @headers = java.util.ArrayList.new
      headers.each do |k, v|
        @headers << HTTPHeader.new(k, v)
      end
      @content = body.to_java_bytes if body
      @status = status
    end
    
    def getResponseCode
      @status
    end
    alias get_response_code getResponseCode
    alias response_code getResponseCode
    
    def getContent
      @content
    end
    alias get_content getContent
    alias content getContent
    
    def getHeaders
      @headers
    end
    alias get_headers getHeaders
    alias headers getHeaders
  end
end

describe AppEngine::URLFetch do
  HTTPRequest = com.google.appengine.api.urlfetch.HTTPRequest
  
  before :each do
    AppEngine::URLFetch.urlfetch_service = mock("URLFetchService")
    @url = 'http://foo.example.com/'
  end
  
  def fetch_and_return(status, body='body', headers={}, &block)
    response = AppEngine::URLFetch::FakeResponse.new(status, body, headers)
    if block
      AppEngine::URLFetch.urlfetch_service.should_receive(:fetch) do |req|
        yield req
        response
      end
    else
      matcher = AppEngine::URLFetch.urlfetch_service.should_receive(:fetch)
      matcher.with(kind_of(HTTPRequest)).and_return(response)
    end
  end
  
  it "should fetch correct url" do
    fetch_and_return(200) do |req|
      req.url.to_string.should == @url
    end
    AppEngine::URLFetch.fetch(@url)
  end
  
  it "should read ok status" do
    fetch_and_return(200)
    
    AppEngine::URLFetch.fetch(@url).should be_a(Net::HTTPOK)
  end

  it "should read error status" do
    fetch_and_return(500)
    AppEngine::URLFetch.fetch(@url).should be_a(Net::HTTPInternalServerError)
  end
  
  it "should read body" do
    fetch_and_return(200, 'foo')
    AppEngine::URLFetch.fetch(@url).body.should == 'foo'
  end
    
  it "should read binary body" do
    fetch_and_return(200, 'bar\0')
    AppEngine::URLFetch.fetch(@url).body.should == 'bar\0'
  end
  
  # TODO can't read fetch options, so there's no way to tell if they're set
end

describe AppEngine::URLFetch::HTTP do
  HTTPRequest = com.google.appengine.api.urlfetch.HTTPRequest
  
  before :each do
    AppEngine::URLFetch.urlfetch_service = mock("URLFetchService")
    @url = 'http://foo.example.com/'
  end
  
  def fetch_and_return(status, body='body', headers={}, &block)
    response = AppEngine::URLFetch::FakeResponse.new(status, body, headers)
    if block
      AppEngine::URLFetch.urlfetch_service.should_receive(:fetch) do |req|
        yield req
        response
      end
    else
      matcher = AppEngine::URLFetch.urlfetch_service.should_receive(:fetch)
      matcher.with(kind_of(HTTPRequest)).and_return(response)
    end
  end
  
  it "should  fetch correct url" do
    fetch_and_return(200) do |req|
      req.url.to_string.should == @url
    end
    AppEngine::URLFetch::HTTP.get URI.parse(@url)
  end
  
  
  it "should read body" do
    fetch_and_return(200, 'foo')
    AppEngine::URLFetch::HTTP.get(URI.parse(@url)).should == 'foo'
  end
  
  it "should support https" do
    @url = 'https://foo.example.com/'
    fetch_and_return(200, 'secure') do |req|
      req.url.to_string.should == @url
    end
    
    uri = URI.parse(@url)
    http = AppEngine::URLFetch::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.get(uri.path).body.should == 'secure'
  end
end