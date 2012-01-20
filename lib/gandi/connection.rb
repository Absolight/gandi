require 'xmlrpc/client'
require 'openssl'

module Gandi
  class Connection
    SSL_VERIFY_MODE = OpenSSL::SSL::VERIFY_NONE

    attr_accessor :apikey
    attr_reader :url
    
    def initialize(apikey, url)
      @apikey = apikey
      @url = url
      connect
    end

    #Calls a RPC method, transparently providing the apikey
    def call(method, *arguments)
      raw_call(method.to_s, @apikey, *arguments)
    end
    
    private

    #Handles RPC calls and exceptions
    def raw_call(*args)
      begin
        @handler.call(*args)
      rescue StandardError => e
        case e
        when XMLRPC::FaultException
          case e.faultCode.to_s.chars.first
          when '1'
            raise Gandi::NoMethodError, e.faultString 
          when '5'
            raise Gandi::DataError, e.faultString
          else
            raise Gandi::ServerError, e.faultString
          end
        else
          raise e
        end
      end
    end
    
    #Instanciates the XMLRPC handler
    def connect
      @handler = XMLRPC::Client.new_from_uri(@url)
      #Get rid of SSL warnings "peer certificate won't be verified in this SSL session"
      #See http://developer.amazonwebservices.com/connect/thread.jspa?threadID=37139
      #and http://blog.chmouel.com/2008/03/21/ruby-xmlrpc-over-a-self-certified-ssl-with-a-warning/
      #and http://stackoverflow.com/questions/4748633/how-can-i-make-rubys-xmlrpc-client-ignore-ssl-certificate-errors for ruby 1.9 (which does not set @ssl_context before a request)
      if @handler.instance_variable_get('@http').use_ssl?
        if @handler.instance_variable_get('@http').instance_variable_get("@ssl_context") #Ruby 1.8.7
          @handler.instance_variable_get('@http').instance_variable_get("@ssl_context").verify_mode = SSL_VERIFY_MODE
        else
          @handler.instance_variable_get('@http').instance_variable_set(:@verify_mode, SSL_VERIFY_MODE) #Ruby 1.9
        end
      end
    end
  end
end
