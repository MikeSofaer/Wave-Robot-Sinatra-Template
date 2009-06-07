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

require 'net/https'


module AppEngine
  # The URLFetch Service provides a way for user code to execute HTTP requests
  # to external URLs.
  #
  # Chunked and hanging requests are not supported, and all content will be
  # returned in a single block.
  #
  # URLFetch::HTTP also provides a drop-in replacement for Net::HTTP.
  # To replace the standard implementation throughout your app you can do:
  #   require 'appengine-apis/urlfetch'
  #   Net::HTTP = AppEngine::URLFetch::HTTP
  module URLFetch
    import com.google.appengine.api.urlfetch.FetchOptions
    import com.google.appengine.api.urlfetch.HTTPHeader
    import com.google.appengine.api.urlfetch.HTTPMethod
    import com.google.appengine.api.urlfetch.HTTPRequest
    import com.google.appengine.api.urlfetch.ResponseTooLargeException
    import com.google.appengine.api.urlfetch.URLFetchServiceFactory
    
    # Raised if the remote service could not be contacted
    class DownloadError < StandardError; end

    # Raised if the url cannot be parsed.
    class InvalidURLError < StandardError; end
    
    # Raised if the response is too large.
    class ResponseTooLargeError < StandardError; end
    
    module_function
    
    # Fetches the given HTTP URL, blocking until the result is returned.
    # 
    # Supported options:
    # [:method] GET, POST, HEAD, PUT, or DELETE
    # [:payload] POST or PUT payload (implies method is not GET, HEAD,
    #            or DELETE)
    # [:headers]
    #    HTTP headers to send with the request. May be a Hash or
    #    Net::HTTPHeaders.
    # [:allow_truncated]
    #    if true, truncate large responses and return them
    #    without error. otherwise, ResponseTooLargeError will be thrown when a
    #    response is truncated.
    # [:follow_redirects]
    #     if true (the default), redirects are transparently followed and the
    #     response (if less than 5 redirects) contains the final destination's
    #     payload and the response status is 200.  You lose, however, the
    #     redirect chaininformation.  If false, you see the HTTP response
    #     yourself, including the 'Location' header, and redirects are not
    #     followed.
    #
    # Returns a Net::HTTPResponse.
    #
    # Throws:
    # - InvalidURLError if the provided url is malformed.
    # - DownloadError if the remote service could not be contacted or the URL
    #   could not be fetched.
    # - ResponseTooLargeError if response truncation has been disabled  and the
    #   response is too large. Some responses are too large to even retrieve
    #   from the remote server, and in these cases the exception is thrown even
    #   if response truncation is enabled.
    #
    def fetch(url, options={})
      request = build_urlfetch_request(url, options)
      begin
        java_response = urlfetch_service.fetch(request)
        return convert_urlfetch_body(java_response)
      rescue java.lang.IllegalArgumentException => ex
        raise ArgumentError, ex.message
      rescue java.net.MalformedURLException => ex
        raise InvalidURLError, ex.message
      rescue java.io.IOException => ex
        raise DownloadError, ex.message
      rescue ResponseTooLargeException => ex
        raise ResponseTooLargeError, ex.message
      end
    end
    
    def build_urlfetch_request(url, options)  # :nodoc:
      method = options.delete(:method) || 'GET'
      payload = options.delete(:payload)
      headers = options.delete(:headers) || {}
      truncate = options.delete(:allow_truncated)
      follow_redirects = options.delete(:follow_redirects) || true
      
      unless options.empty?
        raise ArgumentError, "Unsupported options #{options.inspect}."
      end
      
      begin
        method = HTTPMethod.value_of(method.to_s.upcase)
      rescue java.lang.IllegalArgumentException
        raise ArgumentError, "Invalid method #{method.inspect}."
      end
      
      if truncate
        options = FetchOptions::Builder.allow_truncate
      else
        options = FetchOptions::Builder.disallow_truncate
      end
      if follow_redirects
        options.follow_redirects
      else
        options.do_not_follow_redirects
      end
      
      url = java.net.URL.new(url) unless url.java_kind_of? java.net.URL
      request = HTTPRequest.new(url, method, options)
      
      iterator = if headers.respond_to?(:canonical_each)
        :canonical_each
      else
        :each
      end
      
      headers.send(iterator) do |name, value|
        request.set_header(HTTPHeader.new(name, value))
      end
      
      if payload
        request.set_payload(payload.as_java_bytes)
      end
      
      return request
    end
    
    def convert_urlfetch_body(java_response)  # :nodoc:
      status = java_response.response_code.to_s
      klass = Net::HTTPResponse.send(:response_class, status)
      mesg = klass.name
      mesg = mesg[4, mesg.size]
      response = klass.new(nil, status, mesg)
      java_response.headers.each do |header|
        response.add_field(header.name, header.value)
      end
      body = if java_response.content
        String.from_java_bytes(java_response.content)
      else
        nil
      end
      response.urlfetch_body = body
      return response
    end
    
    def urlfetch_service  # :nodoc:
      @service ||= URLFetchServiceFactory.getURLFetchService
    end
    
    def urlfetch_service=(service)  # :nodoc:
      @service = service
    end

    
    # A subclass of Net::HTTP that makes requests using Google App Engine's
    # URLFetch Service.
    #
    # To replace the standard implementation throughout your app you can do:
    #   require 'appengine-apis/urlfetch'
    #   Net::HTTP = AppEngine::URLFetch::HTTP
    class HTTP < Net::HTTP
      alias connect on_connect

      def request(req, body=nil, &block)
        begin
          proto = use_ssl? ? 'https' : 'http'
          url = "#{proto}://#{addr_port}#{req.path}"
          options = {
              :payload => body,
              :follow_redirects => false,
              :allow_truncated => true,
              :method => req.method,
              :headers => req
              }
          res = URLFetch.fetch(url, options)
        end while res.kind_of?(Net::HTTPContinue)
        res.reading_body(nil, req.response_body_permitted?) {
          yield res if block_given?
        }
        return res
      end
    end
  end
end

module Net  # :nodoc:
  class HTTPResponse  # :nodoc:
    alias stream_check_without_urlfetch stream_check
  
    def stream_check
      return if @urlfetch_body
      stream_check_without_urlfetch
    end
  
    alias read_body_0_without_urlfetch read_body_0

    def read_body_0(dest)
      if @urlfetch_body
        dest << @urlfetch_body
        return
      else
        read_body_0_without_urlfetch(dest)
      end
    end
  
    def urlfetch_body=(body)
      @body_exist = body && self.class.body_permitted?
      @urlfetch_body = body || ''
    end
  end
end