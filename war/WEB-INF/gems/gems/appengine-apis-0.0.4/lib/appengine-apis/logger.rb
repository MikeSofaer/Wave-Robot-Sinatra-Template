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
# Replacement for the standard logger.rb which uses the Google App Engine
# logging API.


require 'appengine-apis/apiproxy'
require 'logger'

module AppEngine
  
  # Replacement for the standard logger.rb. Saves logs to the App Engine
  # Dashboard (or to the java logging api when running locally).
  #
  #   logger = AppEngine::Logger.new
  #   logger.warn "foobar"
  #
  # or (for compatibility with code already using logger.rb)
  #
  #  Logger = AppEngine::Logger
  #  logger = Logger.new(stream)  # stream is ignored
  #  logger.info "Hello, dashboard"
  class Logger < ::Logger
    SEVERITIES = {
      DEBUG => ApiProxy::LogRecord::Level::debug,
      INFO => ApiProxy::LogRecord::Level::info,
      WARN => ApiProxy::LogRecord::Level::warn,
      ERROR => ApiProxy::LogRecord::Level::error,
      FATAL => ApiProxy::LogRecord::Level::fatal,
    }
    SEVERITIES.default = ApiProxy::LogRecord::Level::info
    
    def initialize(*args)
      super(STDERR)
    end
    
    def <<(msg)
      write_log(INFO, msg.to_s, "")
    end
    
    def add(severity, msg=nil, progname=nil, &block)
      severity ||= UNKNOWN
      return if severity < @level
      progname ||= @progname
      if msg.nil?
        if block_given?
          msg = yield
        else
          msg = progname
          progname = @progname
        end
      end
      write_log(severity, msg, progname)
    end
    alias log add

    private
    def write_log(severity, msg, progname)
      level = SEVERITIES[severity]
      if progname && !progname.empty? && progname != msg
        msg = "#{progname}: #{msg}"
      end
      ApiProxy.log(level, msg)
    end
  end
end