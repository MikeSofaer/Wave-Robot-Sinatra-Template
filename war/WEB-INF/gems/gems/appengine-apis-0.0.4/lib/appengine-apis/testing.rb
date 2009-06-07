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
# Helpers for installing stub apis in unit tests.


require 'appengine-apis/apiproxy'

module AppEngine
  
  # Local testing support for Google App Engine
  #
  # If you run your code on Google's servers or under dev_appserver,
  # the api's are already configured.
  #
  # To run outside this environment, you need to install a test environment and
  # api stubs.
  module Testing

    class TestEnv  # :nodoc:
      include AppEngine::ApiProxy::Environment
      
      attr_writer :appid, :version, :email, :admin
      attr_writer :auth_domain, :request_namespace, :default_namespace
      
      def initialize
        @appid = "test"
        @version = "1.0"
        @auth_domain = @request_namespace = "gmail.com"
        @default_namespace = ""
        @email = ""
      end
      
      def getAppId
        @appid
      end
      
      def getVersionId
        @version
      end
      
      def getEmail
        @email
      end
      
      def isLoggedIn
        !(@email.nil? || @auth_domain.nil? || @email.empty?)
      end
      
      def isAdmin
        !!@admin
      end
      
      def getAuthDomain
        @auth_domain
      end
      
      def getRequestNamespace
        @request_namespace
      end
      
      def getDefaultNamespace
        @default_namespace
      end
      
      def setDefaultNamespace(s)
        @default_namespace = s
      end
      
      def inspect
        "#<TestEnv>"
      end
    end
    
    class << self
      
      # Install a test environment for the current thread.
      #
      # You must call this before making any api calls.
      #
      # Note that Google's production and local environments are
      # single threaded. You may run into problems if you use multiple
      # threads.
      def install_test_env
        env = TestEnv.new
        ApiProxy::setEnvironmentForCurrentThread(env)
        env
      end
      
      def factory  # :nodoc:
        @factory ||= AppEngine::SDK.load_local_apiproxy_factory.new
      end
      
      # The application directory, or '.' if not set.
      # Composite index definitions are written to "#{app_dir}/WEB-INF/".
      def app_dir
        file = factory.getApplicationDirectory
        file && file.path
      end

      # Sets the application directory. Should be called before
      # creating stubs.
      #
      # Composite index definitions are written to "#{app_dir}/WEB-INF/".      
      def app_dir=(dir)
        factory.setApplicationDirectory(java.io.File.new(dir))
      end
      
      # Install stub apis and force all datastore operations to use
      # an in-memory datastore.
      #
      # You may call this multiple times to reset to a new in-memory datastore.
      def install_test_datastore
        delegate = install_api_stubs
        lds = Java.ComGoogleAppengineApiDatastoreDev.LocalDatastoreService
        
        delegate.set_property(
            lds::NO_STORAGE_PROPERTY, "true")
        delegate.set_property(
            lds::MAX_QUERY_LIFETIME_PROPERTY,
            java.lang.Integer::MAX_VALUE.to_s)
        delegate.set_property(
            lds::MAX_TRANSACTION_LIFETIME_PROPERTY,
            java.lang.Integer::MAX_VALUE.to_s)
        ApiProxy::setDelegate(delegate)
        delegate
      end
      
      # Install stub apis. The datastore will be written to the disk
      # inside #app_dir.
      #
      # You could potentially use this to run under a ruby web server
      # instead of dev_appserver. In that case you will need to install
      # and configure a test environment for each request.
      def install_api_stubs
        current_delegate = ApiProxy.delegate
        current_delegate.stop if current_delegate.respond_to? :stop

        self.app_dir = '.' if app_dir.nil?
        delegate = factory.create
        ApiProxy::setDelegate(delegate)
        at_exit do
          delegate.stop
        end
        delegate
      end
      
      # Loads stub API implementations if no API implementation is
      # currently configured.
      #
      # Sets up a datastore saved to disk in +app_dir+. +app_dir+ defaults
      # to ENV['APPLICATION_ROOT'] or '.' if not specified.
      #
      # Does nothing is APIs are already configured (e.g. in production).
      #
      # As a shortcut you can use
      #   require 'appengine-apis/local_boot'
      # 
      def boot(app_dir=nil)
        app_dir ||= ENV['APPLICATION_ROOT'] || '.'
        unless AppEngine::ApiProxy.current_environment
          env = install_test_env
          appid = get_app_id(app_dir)
          env.appid = appid if appid
        end
        unless AppEngine::ApiProxy.delegate
          self.app_dir = app_dir
          install_api_stubs
        end
      end
      
      # Looks for app.yaml or WEB-INF/appengine-web.xml in +app_dir+
      # and parses the application id.
      def get_app_id(app_dir)
        aeweb_path = File.join(app_dir, 'WEB-INF', 'appengine-web.xml')
        app_yaml_path = File.join(app_dir, 'app.yaml')
        if File.exist?(app_yaml_path)
          app_yaml = YAML.load(File.open(app_yaml_path))
          return app_yaml['application']
        elsif File.exist?(aeweb_path)
          require 'rexml/document'
          aeweb = REXML::Document.new(File.new(aeweb_path))
          return aeweb.root.elements['application'].text
        end
      end
      
    end

  end
end