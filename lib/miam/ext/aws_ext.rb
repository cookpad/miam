# XXX: see https://github.com/aws/aws-sdk-core-ruby/pull/171
module Seahorse
  module Util
    IAM_paginators_json = /\bIAM.paginators.json\z/

    class << self
      alias orig_load_json load_json

      def load_json(path)
        json = orig_load_json(path)

        if IAM_paginators_json =~ path
          add_GetAccountAuthorizationDetails_paginator(json)
        else
          json
        end
      end

      private

      def add_GetAccountAuthorizationDetails_paginator(json)
        json["pagination"]["GetAccountAuthorizationDetails"] = {
          "input_token" => "Marker",
          "output_token" => "Marker",
          "more_results" => "IsTruncated",
          "limit_key" => "MaxItems",
        }

        json
      end
    end
  end
end
