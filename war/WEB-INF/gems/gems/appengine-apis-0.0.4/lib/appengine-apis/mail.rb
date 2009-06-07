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
  
  # App Engine applications can send email messages on behalf of the app's
  # administrators, and on behalf of users with Google Accounts. Apps use the
  # Mail service to send email messages.
  #
  # The Mail.send method sends an email message from the application. The From:
  # address can be either the email address of a registered administrator
  # (developer) of the application, or the current user if signed in with
  # Google Accounts.
  #
  # The following example sends an email message to the user as confirmation
  # that the user created a new account with the application:
  #
  #   class SignupController < Merb::Controller
  #     def confirm(self):
  #       user_address = params[:email_address"]
  #      confirmation_url = create_new_user_confirmation
  #      sender_address = "support@example.com"
  #      subject = "Confirm your registration"
  #      body = <<EOM
  #   Thank you for creating an account!  Please confirm your email address by
  #   clicking on the link below:
  #   
  #   #{confirmation_url}
  #   EOM
  #   
  #      AppEngine::Mail.send(sender_address, user_address, subject, body)
  #    end
  #  end
  module Mail
    import com.google.appengine.api.mail.MailServiceFactory
    import com.google.appengine.api.mail.MailService
    
    module_function

    # Sends an email.
    #
    # The message will be delivered asynchronously, and delivery problems
    # will result in a bounce to the specified sender.
    #
    # Args:
    # [sender] The From: field of the email. Must correspond to the valid
    #          email address of one of the admins for this application, or
    #          to the email address of the currently logged-in user.
    # [to] Message recipient(s). Should be an email address, or an Array
    #      of email addresses.
    # [subject] Subject of the message.
    # [text] Plain text body of the message. To send an HTML only email,
    #        set +text+ to nil and use the +:html+ option.
    # [options] See #create_java_message for supported options.
    def send(sender, to, subject, text, options={})
      orig_options = options
      options = {
        :sender => sender,
        :to => to || [],
        :subject => subject,
        :text => text
      }
      options.merge!(orig_options)
      message = create_java_message(options)
      convert_mail_exceptions { service.send(message) }
    end

    # Sends an email alert to all admins of an application.
    #
    # The message will be delivered asynchronously, and delivery problems
    # will result in a bounce to the admins.
    #
    # Args:
    # [sender] The From: field of the email. Must correspond to the valid
    #          email address of one of the admins for this application, or
    #          to the email address of the currently logged-in user.
    # [subject] Subject of the message.
    # [text] Plain text body of the message. To send an HTML only email,
    #        set +text+ to nil and use the +:html+ option.
    # [options] See #create_java_message for supported options.    
    def send_to_admins(sender, subject, text, options={})
      orig_options = options
      options = {
        :sender => sender,
        :subject => subject,
        :text => text
      }
      options.merge!(orig_options)
      message = create_java_message(options)
      convert_mail_exceptions { service.send_to_admins(message) }
    end
    
    # Creates a Java MailService.Message object.
    #
    # Supported options:
    # [:atttachments]
    #   Attachments to send with this message. Should be a Hash of
    #   {"filename" => "data"} or an Array of [["filename", "data"], ...].
    # [:bcc] Must be a String or an Array of Strings if set.
    # [:cc] Must be a String or an Array of Strings if set.
    # [:html] The html body of the message. Must not be +nil+ if +text+ is nil.
    # [:reply_to] Must be a valid email address if set.
    def create_java_message(options)
      options[:text_body] = options.delete(:text)
      options[:html_body] = options.delete(:html)
      attachments = options[:attachments]
      if attachments
        options[:attachments] = attachments.collect do |filename, data|
          MailService::Attachment.new(filename, data.to_java_bytes)
        end
      end
      [:to, :cc, :bcc].each do |key|
        value = options[key]
        options[key] = [value] if value.kind_of? String
      end
      message = MailService::Message.new
      options.each do |key, value|
        begin
          message.send("set_#{key}", value) if value
        rescue NameError
          raise ArgumentError, "Invalid option #{key.inspect}."
        end
      end
      return message
    end
    
    def convert_mail_exceptions  # :nodoc:
      begin
        yield
      rescue java.lang.IllegalArgumentException => ex
        raise ArgumentError, ex.message
      rescue java.io.IOException => ex
        raise IOError, ex.message
      end
    end
    
    def service  # :nodoc:
      @service ||= MailServiceFactory.mail_service
    end
    
    def service=(service)  # :nodoc:
      @service = service
    end
  end
end