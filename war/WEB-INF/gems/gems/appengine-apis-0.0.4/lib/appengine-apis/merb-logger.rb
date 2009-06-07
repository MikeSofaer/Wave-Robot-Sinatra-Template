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
# Switches the Merb Logger class to use the Google App Engine logging API.

require 'merb-core/logger'
require 'appengine-apis/apiproxy.rb'

module Merb  # :nodoc:
  
  # Modifies the Merb Logger class to save logs using the Logging API
  # instead of writing directly to a stream.
  class Logger
    def <<(string = nil)
      AppEngine::ApiProxy.log(
          AppEngine::ApiProxy::LogRecord::Level::info, string)
    end
    alias :push :<<

    # Re-generate the logging methods for Merb.logger for each log level.
    Levels.each_pair do |name, number|
      class_eval <<-LEVELMETHODS, __FILE__, __LINE__

      # Appends a message to the log if the log level is at least as high as
      # the log level of the logger.
      #
      # ==== Parameters
      # string<String>:: The message to be logged. Defaults to nil.
      #
      # ==== Returns
      # self:: The logger object for chaining.
      def #{name}(message = nil)
        if #{number} >= level
          message = block_given? ? yield : message
          AppEngine::ApiProxy.log(
              AppEngine::ApiProxy::LogRecord::Level::#{name}, message)
        end
        self
      end
      alias :#{name}! :#{name}
      LEVELMETHODS
    end
  end
end