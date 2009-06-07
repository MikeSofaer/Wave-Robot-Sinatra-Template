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

module AppEngine
  # Users provides information useful for forcing a user to log in or out, and
  # retrieving information about the user who is currently logged-in.
  module Users
    import com.google.appengine.api.users.User
    import com.google.appengine.api.users.UserServiceFactory
    
    Service = UserServiceFactory.getUserService
    
    class << self
      
      # If the user is logged in, this method will return a User that contains
      # information about them. Note that repeated calls may not necessarily
      # return the same User object.
      def current_user
        Service.current_user
      end
      
      # Computes the login URL for this request and specified destination URL.
      # 
      # Args:
      # - dest_url: The desired final destination URL for the user
      #             once login is complete. If +dest_url+ does not have a host
      #             specified, we will use the host from the current request.
      def create_login_url(url)
        Service.create_login_url(url)
      end
      
      # Computes the logout URL for this request and specified destination URL.
      # 
      # Args:
      # - dest_url: String that is the desired final destination URL for the
      #             user once logout is complete. If +dest_url+ does not have
      #             a host specified, uses the host from the current request.
      def create_logout_url(url)
        Service.create_logout_url(url)
      end
      
      # Returns true if there is a user logged in, false otherwise.
      def logged_in?
        Service.is_user_logged_in?
      end
      
      # Returns true if the user making this request is an admin for this
      # application, false otherwise.
      # 
      # This is a separate function, and not a member function of the User
      # class, because admin status is not persisted in the datastore. It
      # only exists for the user making this request right now.
      def admin?
        Service.is_user_admin?
      end
    end
    
    # User represents a specific user, represented by the combination of an
    # email address and a specific Google Apps domain (which we call an
    # auth_domain). For normal Google login, authDomain will be set to
    # "gmail.com".
    class User
      alias == equals?
      alias to_s toString
      
      class << self
        alias java_new new  # :nodoc:
        
        # Creates a new User.
        #
        # Args:
        # - email: a non-nil email address.
        # - auth_domain: an optinoal domain name into which this user has
        #   authenticated, or "gmail.com" for normal Google authentication.
        def new(email, auth_domain=nil)
          unless auth_domain
            env = AppEngine::ApiProxy.current_environment
            auth_domain = if env
              env.getAuthDomain
            else
              'gmail.com'
            end
          end
          
          java_new(email, auth_domain)
        end
      end
      
      if nil  # rdoc only
        # Return this user's nickname. The nickname will be a unique, human
        # readable identifier for this user with respect to this application.
        # It will be an email address for some users, but not all.
        def nickname
        end
        
        def auth_domain
        end
        
        def email
        end
      end
    end
  end
end