require 'remit/common'

module Remit
  module VerifySignature
    class Request < Remit::Request
      action :VerifySignature
      parameter :url_end_point, :required => true
      parameter :http_parameters, :required => true
      parameter :version, :required => true
    end

    # "<?xml version=\"1.0\"?>
    # <VerifySignatureResponse xmlns=\"http://fps.amazonaws.com/doc/2008-09-17/\">
    # <VerifySignatureResult>
    # <VerificationStatus>Success</VerificationStatus>
    # </VerifySignatureResult><ResponseMetadata><RequestId>eb98d261-527e-42af-b523-e1e7ce7c5d4b:0</RequestId></ResponseMetadata></VerifySignatureResponse>
    
    class Response < Remit::Response
      parameter :verify_signature_result
      parameter :response_metadata
      
      def verified?
        self.verify_signature_result == "Success"
      end
    end

    def verify_signature(request = Request.new)
      call(request, Response)
    end
  end
end
