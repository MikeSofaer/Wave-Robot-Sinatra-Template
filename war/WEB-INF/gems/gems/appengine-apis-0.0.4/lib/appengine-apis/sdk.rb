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

require 'java'

module AppEngine
  
  # Helper methods to locate the App Engine SDK and add it to the class path.
  module SDK
    class << self

      # Tries to load the ApiProxy class.
      def load_apiproxy
        with_jars(%w{lib impl appengine-api.jar}) do
          return Java.ComGoogleApphostingApi.ApiProxy
        end
      end
      
      # Tries to load the ApiProxyLocalFactory class.
      def load_local_apiproxy_factory
        with_jars(%w{lib shared appengine-local-runtime-shared.jar},
                  %w{lib impl appengine-api-stubs.jar},
                  %w{lib impl appengine-local-runtime.jar}
                  ) do
          return Java.ComGoogleAppengineToolsDevelopment.ApiProxyLocalFactory
        end
      end
      
      def with_jars(*jars)  # :nodoc:
        begin
          failed = false
          yield
        rescue NameError => ex
          if failed
            raise ex
          else
            failed = true
            jars.each do |jar|
              $CLASSPATH << sdk_path(*jar)
            end
            retry
          end
        end
      end
      
      # Tries to find the Google App Engine SDK for Java.
      #
      # Looks for appcfg.sh in these directories (in order):
      # - ENV['APPENGINE_JAVA_SDK']/bin
      # - each directory in ENV['PATH']
      # - '/usr/local/appengine-java-sdk/bin'
      # - 'c:\appengine-java-sdk\bin'
      #
      # Returns File.join(sdk_directory, *pieces)
      #
      def sdk_path(*pieces)
        unless @sdk_path
          begin
            require 'reggae'
            @sdk_path = AppEngine::Jars::Path
          rescue Exception
            base_path = File.join(ENV['APPENGINE_JAVA_SDK'] || '', 'bin')
            exec_paths = ENV['PATH'].split(File::PATH_SEPARATOR)
            exec_paths << '/usr/local/appengine-java-sdk/bin'
            exec_paths << 'c:\appengine-java-sdk\bin'
          
            while !exec_paths.empty?
              if File.exist?(File.join(base_path, 'appcfg.sh'))
                @sdk_path = File.dirname(base_path)
                return File.join(@sdk_path, *pieces)
              end
              base_path = exec_paths.shift
            end
            raise "Unable to locate the Google App Engine SDK for Java."
          end
        end
        File.join(@sdk_path, *pieces)
      end
    end
  end
end