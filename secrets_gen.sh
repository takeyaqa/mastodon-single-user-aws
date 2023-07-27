#!/usr/bin/env ruby

require 'securerandom'
require 'openssl'
require 'base64'

# https://github.com/mastodon/mastodon/blob/v4.1.5/lib/tasks/mastodon.rake#L33-L35
puts "SECRET_KEY_BASE=#{SecureRandom.hex(64)}"
puts "OTP_SECRET=#{SecureRandom.hex(64)}"

# https://github.com/ClearlyClaire/webpush/blob/f14a4d52e201128b1b00245d11b6de80d6cfdcd9/lib/webpush/vapid_key.rb
curve = OpenSSL::PKey::EC.generate('prime256v1')
public_key = Base64.urlsafe_encode64(curve.public_key.to_bn.to_s(2))
private_key = Base64.urlsafe_encode64(curve.private_key.to_s(2))

puts "VAPID_PRIVATE_KEY=#{private_key}"
puts "VAPID_PUBLIC_KEY=#{public_key}"
