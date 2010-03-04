require 'base64'
require 'erb'
require 'uri'

require 'rubygems'
require 'relax'

module Remit
  class Request < Relax::Request
    def self.action(name)
      parameter :action, :value => name
    end

    def convert_key(key)
      key.to_s.gsub(/(^|_)(.)/) { $2.upcase }.to_sym
    end
    protected :convert_key
  end

  class BaseResponse < Relax::Response
    def node_name(name, namespace=nil)
      super(name.to_s.gsub(/(^|_)(.)/) { $2.upcase }, namespace)
    end
  end

  class Response < BaseResponse
    parameter :request_id

    attr_accessor :status
    attr_accessor :errors

    def initialize(xml)
      super

      if is?(:Response) && has?(:Errors)
        @errors = elements(:Errors).collect do |error|
          Error.new(error)
        end
      else
        @status = text_value(element(:Status))
        @errors = elements('Errors/Errors').collect do |error|
          ServiceError.new(error)
        end unless successful?
      end
    end

    def successful?
      @status == ResponseStatus::SUCCESS
    end

    def node_name(name, namespace=nil)
      super(name.to_s.split('/').collect{ |tag|
        tag.gsub(/(^|_)(.)/) { $2.upcase }
      }.join('/'), namespace)
    end
  end

  class SignedQuery < Relax::Query
    API_VERSION = '2009-01-09'.freeze
    SIGNATURE_VERSION = 2.freeze
    SIGNATURE_METHOD = 'HmacSHA256'.freeze

    def initialize(uri, secret_key, query={})
      super(query)
      @uri = URI.parse(uri.to_s)
      @secret_key = secret_key
    end

    def to_s(http_method='GET')
      sign(http_method) if http_method
      super()
    end

    private

    def sign(http_method)
      # exclude this from the new signature if it's already set
      delete :Signature

      self[:Version] = API_VERSION
      self[:SignatureVersion] = SIGNATURE_VERSION
      self[:SignatureMethod] = SIGNATURE_METHOD
      self[:Signature] = compute_signature(http_method)
    end

    def compute_signature(http_method)
      method = http_method.to_s.upcase
      host = @uri.host
      path = @uri.request_uri
      encoded_data = to_s(nil).gsub(/\+/, '%20')

      data = "#{http_method}\n#{host}\n#{path}\n#{encoded_data}"
      digest = OpenSSL::HMAC.digest(OpenSSL::Digest::SHA256.new, @secret_key, data)
      Base64.encode64(digest).strip
    end

    class << self
      def parse(uri, secret_key, query_string)
        query = self.new(uri, secret_key)

        query_string.split('&').each do |parameter|
          key, value = parameter.split('=', 2)
          query[key] = unescape_value(value)
        end

        query
      end
    end
  end
end
