require 'spaceship'
require 'base64'
require 'fileutils'

puts "🔐 Initializing Spaceship App Store Connect API Token..."
key_id = ENV['APP_STORE_CONNECT_KEY_ID']
issuer_id = ENV['APP_STORE_CONNECT_ISSUER_ID']
key_content = ENV['APP_STORE_CONNECT_API_KEY']
dev_team = ENV['DEV_TEAM'] || 'V7J345DY58'

key_path = File.expand_path("~/.appstoreconnect/private_keys/AuthKey_#{key_id}.p8")
if File.exist?(key_path)
  key_content = File.read(key_path)
end

token = Spaceship::ConnectAPI::Token.create(
  key_id: key_id,
  issuer_id: issuer_id,
  filepath: key_path,
  key: key_content,
  in_house: false
)
Spaceship::ConnectAPI.token = token

# 1. Setup Keychain and Intermediate Certificates
keychain_path = "/tmp/build.keychain"
password = "buildpassword"
puts "🔑 Configuring build keychain..."
system("security create-keychain -p #{password} #{keychain_path} 2>/dev/null || true")
system("security set-keychain-settings -lut 21600 #{keychain_path}")
system("security unlock-keychain -p #{password} #{keychain_path}")

out = `security list-keychains -d user`.to_s
existing = out.split("\n").map { |k| k.strip.gsub('"', '') }.reject(&:empty?)
all_kcs = ([keychain_path] + existing).uniq
system("security list-keychains -d user -s #{all_kcs.join(' ')}")

# Download and install Apple Root CA and WWDR intermediate certificates
wwdr_urls = [
  "https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer",
  "https://www.apple.com/certificateauthority/AppleWWDRCAG6.cer",
  "https://www.apple.com/appleca/AppleIncRootCertificate.cer"
]
wwdr_urls.each do |url|
  fname = File.basename(url)
  system("curl -s -f -L '#{url}' -o '/tmp/#{fname}' && security import '/tmp/#{fname}' -k #{keychain_path} -T /usr/bin/codesign -T /usr/bin/security 2>/dev/null || true")
end

# 2. Check / Create Distribution Certificate in Keychain & Developer Portal
active_cert = nil
identities = `security find-identity -v -p codesigning`.to_s

puts "📋 Checking existing certificates on App Store Connect..."
dist_certs = Spaceship::ConnectAPI::Certificate.all(filter: { certificateType: "DISTRIBUTION" })

if identities.include?("Apple Distribution") && dist_certs.any?
  puts "✅ Apple Distribution identity already exists in keychain and developer portal."
  active_cert = dist_certs.first
else
  puts "🚀 Ensuring Distribution Certificate via Spaceship..."
  dist_key_path = "/tmp/dist.key"
  csr_path = "/tmp/dist.csr"
  system("openssl genrsa -out #{dist_key_path} 2048")
  system("openssl req -new -key #{dist_key_path} -out #{csr_path} -subj '/CN=Apple Distribution: Forma/O=#{dev_team}'")
  csr_content = File.read(csr_path)

  begin
    active_cert = Spaceship::ConnectAPI::Certificate.create(
      certificate_type: "DISTRIBUTION",
      csr_content: csr_content
    )
    puts "✅ Created certificate ID: #{active_cert.id}"
  rescue => e
    puts "⚠️ Certificate creation note: #{e.message}. Checking existing certs..."
    dist_certs = Spaceship::ConnectAPI::Certificate.all(filter: { certificateType: "DISTRIBUTION" })
    if dist_certs.any?
      puts "Found #{dist_certs.count} existing distribution certs. Revoking oldest to ensure fresh keypair..."
      oldest = dist_certs.sort_by { |c| c.expiration_date.to_s }.first
      begin
        oldest.delete!
        puts "Deleted cert #{oldest.id}"
        sleep(2)
        active_cert = Spaceship::ConnectAPI::Certificate.create(
          certificate_type: "DISTRIBUTION",
          csr_content: csr_content
        )
        puts "✅ Created certificate ID: #{active_cert.id}"
      rescue => del_err
        puts "Note during revoke/create: #{del_err.message}"
        active_cert = dist_certs.first
      end
    end
  end

  if active_cert && File.exist?(dist_key_path)
    cer_path = "/tmp/dist.cer"
    pem_path = "/tmp/dist.pem"
    p12_path = "/tmp/dist.p12"
    File.binwrite(cer_path, Base64.decode64(active_cert.certificate_content))
    system("openssl x509 -inform der -in #{cer_path} -out #{pem_path}")
    system("openssl pkcs12 -export -inkey #{dist_key_path} -in #{pem_path} -out #{p12_path} -passout pass:#{password} -name 'Apple Distribution: Forma'")
    system("security import #{p12_path} -k #{keychain_path} -P #{password} -T /usr/bin/codesign -T /usr/bin/security")
    system("security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k #{password} #{keychain_path}")
    puts "✅ Certificate imported into keychain!"
  end
end

active_cert_id = active_cert&.id || dist_certs.first&.id
puts "🎯 Active Certificate ID: #{active_cert_id}"

# 3. Ensure Bundle IDs and Capabilities
target_bundles = {
  'com.samvel.forma' => 'Forma AppStore',
  'com.samvel.forma.widgets' => 'Forma Widgets AppStore',
  'com.samvel.forma.watchkitapp' => 'Forma Watch AppStore'
}

puts "📋 Ensuring Bundle IDs exist..."
all_bundle_ids = Spaceship::ConnectAPI::BundleId.all

target_bundles.each do |bid_str, prof_name|
  target_bid = all_bundle_ids.find { |b| b.identifier == bid_str }
  if target_bid.nil?
    puts "Creating new Bundle ID: #{bid_str} (#{prof_name})..."
    begin
      target_bid = Spaceship::ConnectAPI::BundleId.create(
        name: prof_name.gsub(' AppStore', ''),
        identifier: bid_str,
        platform: "UNIVERSAL"
      )
      puts "  ✅ Created Bundle ID: #{bid_str}"
    rescue => err
      puts "  ⚠️ Bundle ID creation note: #{err.message}"
    end
  else
    puts "  ✅ Bundle ID exists: #{bid_str}"
  end
  
  # Enable capabilities if needed
  if target_bid && bid_str == 'com.samvel.forma'
    ['HEALTHKIT', 'APP_GROUPS'].each do |cap|
      begin
        Spaceship::ConnectAPI::BundleIdCapability.create(
          bundle_id_id: target_bid.id,
          capability_type: cap
        )
        puts "  ✅ Enabled capability #{cap} for #{bid_str}"
      rescue => cap_err
        # Capability may already be active
      end
    end
  elsif target_bid && bid_str == 'com.samvel.forma.widgets'
    begin
      Spaceship::ConnectAPI::BundleIdCapability.create(
        bundle_id_id: target_bid.id,
        capability_type: 'APP_GROUPS'
      )
      puts "  ✅ Enabled capability APP_GROUPS for #{bid_str}"
    rescue => cap_err
      # Capability may already be active
    end
  end
end

# Refresh Bundle IDs
all_bundle_ids = Spaceship::ConnectAPI::BundleId.all

# 4. Fetch or Create Provisioning Profiles for all Bundle IDs
profiles_out_dir = "/tmp/profiles"
FileUtils.mkdir_p(profiles_out_dir)
installed_profiles_dir = File.expand_path("~/Library/MobileDevice/Provisioning Profiles")
FileUtils.mkdir_p(installed_profiles_dir)

puts "📋 Fetching and validating Provisioning Profiles for all targets..."
all_profiles = Spaceship::ConnectAPI::Profile.all(includes: "bundleId,certificates")

target_bundles.each do |bid_str, prof_name|
  target_bid = all_bundle_ids.find { |b| b.identifier == bid_str }
  matching_profile = all_profiles.find do |p|
    p.bundle_id&.identifier == bid_str && 
    (p.profile_type.to_s.include?("APP_STORE") || p.profile_type.to_s.include?("DISTRIBUTION"))
  end
  
  # If matching profile does not exist or certs need refresh, create a new one
  if matching_profile.nil? && target_bid && active_cert_id
    puts "Creating new App Store profile for #{bid_str} with cert #{active_cert_id}..."
    prof_type = bid_str.include?("watch") ? "WATCHOS_APP_STORE" : "IOS_APP_STORE"
    begin
      matching_profile = Spaceship::ConnectAPI::Profile.create(
        name: prof_name,
        profile_type: prof_type,
        bundle_id_id: target_bid.id,
        certificate_ids: [active_cert_id]
      )
      puts "  ✅ Created profile #{prof_name}"
    rescue => err
      puts "  ⚠️ Profile creation note (#{prof_type}): #{err.message}. Retrying as IOS_APP_STORE..."
      begin
        matching_profile = Spaceship::ConnectAPI::Profile.create(
          name: prof_name,
          profile_type: "IOS_APP_STORE",
          bundle_id_id: target_bid.id,
          certificate_ids: [active_cert_id]
        )
      rescue => fallback_err
        puts "  ⚠️ Fallback profile create error: #{fallback_err.message}"
      end
    end
  end

  if matching_profile
    content_b64 = matching_profile.profile_content
    if content_b64
      # Write named profile for direct CI extraction
      named_path = File.join(profiles_out_dir, "#{bid_str}.mobileprovision")
      File.binwrite(named_path, Base64.decode64(content_b64))
      
      # Write UUID profile for Xcode
      uuid_path = File.join(installed_profiles_dir, "#{matching_profile.uuid}.mobileprovision")
      File.binwrite(uuid_path, Base64.decode64(content_b64))
      puts "  ✅ Provisioning Profile ready for #{bid_str} -> #{matching_profile.name} (#{matching_profile.uuid})"
      
      if bid_str == 'com.samvel.forma' && ENV['GITHUB_ENV']
        File.open(ENV['GITHUB_ENV'], 'a') do |f|
          f.puts("PROFILE_NAME=#{matching_profile.name}")
          f.puts("PROFILE_UUID=#{matching_profile.uuid}")
        end
      end
    end
  else
    puts "  ⚠️ Warning: Could not find or create profile for #{bid_str}"
  end
end

puts "🎉 Provisioning setup complete!"
