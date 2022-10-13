# frozen_string_literal: true

module JWT
  module JWK
    class HMAC < KeyBase
      KTY  = 'oct'
      KTYS = [KTY, String].freeze
      HMAC_PUBLIC_KEY_ELEMENTS = %i[kty].freeze
      HMAC_PRIVATE_KEY_ELEMENTS = %i[k].freeze
      HMAC_KEY_ELEMENTS = (HMAC_PRIVATE_KEY_ELEMENTS + HMAC_PUBLIC_KEY_ELEMENTS).freeze

      def initialize(keypair, params = nil, options = {})
        params ||= {}

        # For backwards compatibility when kid was a String
        params = { kid: params } if params.is_a?(String)

        # Accept String key as input
        keypair = { kty: KTY, k: keypair } if keypair.is_a?(String)

        raise ArgumentError, 'keypair must be of type String' unless keypair.is_a?(Hash)

        keypair = keypair.transform_keys(&:to_sym)
        params  = params.transform_keys(&:to_sym)
        check_jwk(keypair, params)

        super(options, keypair.merge(params))
      end

      def keypair
        self[:k]
      end

      def private?
        true
      end

      def public_key
        nil
      end

      # See https://tools.ietf.org/html/rfc7517#appendix-A.3
      def export(options = {})
        exported = parameters.clone
        exported.reject! { |k, _| HMAC_PRIVATE_KEY_ELEMENTS.include? k } unless private? && options[:include_private] == true
        exported
      end

      def members
        HMAC_KEY_ELEMENTS.each_with_object({}) { |i, h| h[i] = self[i] }
      end

      alias signing_key keypair # for backwards compatibility

      def key_digest
        sequence = OpenSSL::ASN1::Sequence([OpenSSL::ASN1::UTF8String.new(signing_key),
                                            OpenSSL::ASN1::UTF8String.new(KTY)])
        OpenSSL::Digest::SHA256.hexdigest(sequence.to_der)
      end

      def []=(key, value)
        if HMAC_KEY_ELEMENTS.include?(key.to_sym)
          raise ArgumentError, 'cannot overwrite cryptographic key attributes'
        end

        super(key, value)
      end

      private

      def check_jwk(keypair, params)
        raise ArgumentError, 'cannot overwrite cryptographic key attributes' unless (HMAC_KEY_ELEMENTS & params.keys).empty?
        raise JWT::JWKError, "Incorrect 'kty' value: #{keypair[:kty]}, expected #{KTY}" unless keypair[:kty] == KTY
        raise JWT::JWKError, 'Key format is invalid for HMAC' unless keypair[:k]
      end

      class << self
        def import(jwk_data)
          new(jwk_data)
        end
      end
    end
  end
end
