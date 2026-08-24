require 'spaceship'
require 'base64'
require 'fileutils'

key_id = ENV['APP_STORE_CONNECT_KEY_ID']
issuer_id = ENV['APP_STORE_CONNECT_ISSUER_ID']
dev_team = ENV['DEV_TEAM'] || 'V7J345DY58'
key_path = File.expand_path("~/.appstoreconnect/private_keys/AuthKey_#{key_id}.p8")

puts "🔐 Initializing Spaceship App Store Connect API Token..."
token = Spaceship::ConnectAPI::Token.create(
  key_id: key_id,
  issuer_id: issuer_id,
  filepath: key_path
)
Spaceship::ConnectAPI.token = token

# 1. Check / Install Provisioning Profiles
profiles_dir = File.expand_path("~/Library/MobileDevice/Provisioning Profiles")
FileUtils.mkdir_p(profiles_dir)

puts "📋 Fetching Provisioning Profiles via Spaceship..."
profiles = Spaceship::ConnectAPI::Profile.all(filter: { profileType: "IOS_APP_STORE,IOS_APP_DEVELOPMENT" }, includes: "bundleId,certificates")
target_profile_name = nil

profiles.each do |p|
  uuid = p.uuid
  name = p.name
  content_b64 = p.profile_content
  if content_b64 && uuid
    file_path = File.join(profiles_dir, "#{uuid}.mobileprovision")
    File.binwrite(file_path, Base64.decode64(content_b64))
    puts "  • Installed Profile: #{name} (#{p.profile_type}) -> #{uuid}.mobileprovision"
    if name.downcase.include?('forma') && (p.profile_type.to_s.downcase.include?('store') || name.downcase.include?('store') || p.profile_type.to_s.downcase.include?('distribution'))
      target_profile_name = name
    end
  end
end

if target_profile_name
  puts "🎯 Target profile selected: #{target_profile_name}"
  if ENV['GITHUB_ENV']
    File.open(ENV['GITHUB_ENV'], 'a') { |f| f.puts("PROFILE_NAME=#{target_profile_name}") }
  end
end

# 2. Check / Create Distribution Certificate in Keychain
keychain_path = "/tmp/build.keychain"
password = "buildpassword"
puts "🔑 Configuring build keychain..."
system("security create-keychain -p #{password} #{keychain_path}")
system("security set-keychain-settings -lut 21600 #{keychain_path}")
system("security unlock-keychain -p #{password} #{keychain_path}")

out = `security list-keychains -d user`.to_s
existing = out.split("\n").map { |k| k.strip.gsub('"', '') }.reject(&:empty?)
all_kcs = ([keychain_path] + existing).uniq
system("security list-keychains -d user -s #{all_kcs.join(' ')}")

identities = `security find-identity -v -p codesigning`.to_s
if identities.include?("Apple Distribution")
  puts "✅ Apple Distribution identity already exists in keychain."
else
  puts "🚀 Creating new Distribution Certificate via Spaceship..."
  key_path = "/tmp/dist.key"
  csr_path = "/tmp/dist.csr"
  system("openssl genrsa -out #{key_path} 2048")
  system("openssl req -new -key #{key_path} -out #{csr_path} -subj '/CN=Apple Distribution: Forma/O=#{dev_team}'")
  csr_content = File.read(csr_path)

  begin
    cert = Spaceship::ConnectAPI::Certificate.create(
      certificate_type: "DISTRIBUTION",
      csr_content: csr_content
    )
    puts "✅ Created certificate ID: #{cert.id}"
    cer_path = "/tmp/dist.cer"
    pem_path = "/tmp/dist.pem"
    p12_path = "/tmp/dist.p12"
    File.binwrite(cer_path, Base64.decode64(cert.certificate_content))
    system("openssl x509 -inform der -in #{cer_path} -out #{pem_path}")
    system("openssl pkcs12 -export -inkey #{key_path} -in #{pem_path} -out #{p12_path} -passout pass:#{password} -name 'Apple Distribution: Forma'")
    system("security import #{p12_path} -k #{keychain_path} -P #{password} -T /usr/bin/codesign -T /usr/bin/security")
    system("security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k #{password} #{keychain_path}")
    puts "✅ Certificate imported into keychain!"
  rescue => e
    puts "⚠️ Certificate creation failed: #{e.message}. Checking existing certs to revoke..."
    certs = Spaceship::ConnectAPI::Certificate.all(filter: { certificateType: "DISTRIBUTION" })
    if certs.any?
      oldest = certs.first
      puts "🗑️ Revoking certificate #{oldest.id}..."
      oldest.delete!
      sleep 2
      retry
    end
  end
end
