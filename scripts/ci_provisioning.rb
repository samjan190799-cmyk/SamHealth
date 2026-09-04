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
puts "🔑 Configuring build keychain at #{keychain_path}..."
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
dist_key_path = "/tmp/dist.key"
csr_path = "/tmp/dist.csr"
cer_path = "/tmp/dist.cer"
pem_path = "/tmp/dist.pem"
p12_path = "/tmp/dist.p12"

puts "🚀 Generating fresh private key and CSR for Apple Distribution..."
system("openssl genrsa -out #{dist_key_path} 2048")
system("openssl req -new -key #{dist_key_path} -out #{csr_path} -subj '/CN=Apple Distribution: Forma/O=#{dev_team}'")
csr_content = File.read(csr_path)

puts "📋 Checking distribution certificates on App Store Connect..."
dist_certs = Spaceship::ConnectAPI::Certificate.all(filter: { certificateType: "DISTRIBUTION" })
puts "Found #{dist_certs.count} existing distribution certs on App Store Connect."

max_attempts = 5
attempt = 0

while active_cert.nil? && attempt < max_attempts
  attempt += 1
  puts "🚀 Attempt #{attempt}/#{max_attempts} to create paired distribution certificate..."
  begin
    active_cert = Spaceship::ConnectAPI::Certificate.create(
      certificate_type: "DISTRIBUTION",
      csr_content: csr_content
    )
    puts "✅ Created fresh distribution certificate ID: #{active_cert.id}"
  rescue => e
    puts "⚠️ Certificate create response (attempt #{attempt}): #{e.message}"
    dist_certs = Spaceship::ConnectAPI::Certificate.all(filter: { certificateType: "DISTRIBUTION" })
    if dist_certs.any?
      oldest = dist_certs.sort_by { |c| c.expiration_date.to_s }.first
      puts "🗑️ Revoking oldest certificate #{oldest.id} to free up distribution slot..."
      begin
        oldest.delete!
        puts "✅ Successfully revoked cert #{oldest.id}. Waiting 4 seconds for Apple API propagation..."
        sleep(4)
      rescue => del_err
        puts "⚠️ Revoke error: #{del_err.message}"
      end
    else
      sleep(3)
    end
  end
end

if active_cert.nil?
  puts "❌ CRITICAL: Failed to create paired distribution certificate after #{max_attempts} attempts!"
  exit 1
end

if active_cert && File.exist?(dist_key_path)
  File.binwrite(cer_path, Base64.decode64(active_cert.certificate_content))
  system("openssl x509 -inform der -in #{cer_path} -out #{pem_path}")
  system("openssl pkcs12 -export -inkey #{dist_key_path} -in #{pem_path} -out #{p12_path} -passout pass:#{password} -name 'Apple Distribution: Forma'")
  system("security import #{p12_path} -k #{keychain_path} -P #{password} -T /usr/bin/codesign -T /usr/bin/security")
  system("security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k #{password} #{keychain_path}")
  puts "✅ Fresh Apple Distribution certificate imported into keychain!"
end

active_cert_id = active_cert.id
puts "🎯 Active Certificate ID for profiles: #{active_cert_id}"

# Extract exact SHA-1 fingerprint of the imported certificate
cert_sha1 = nil
if File.exist?(cer_path)
  raw_fp = `openssl x509 -inform der -in #{cer_path} -noout -fingerprint -sha1`.to_s
  cert_sha1 = raw_fp.split('=').last.to_s.strip.gsub(':', '')
  puts "🎯 Active Certificate SHA-1 Fingerprint: #{cert_sha1}"
  File.write("/tmp/signing_identity.txt", cert_sha1)
  if ENV['GITHUB_ENV']
    File.open(ENV['GITHUB_ENV'], 'a') { |f| f.puts("SIGNING_IDENTITY=#{cert_sha1}") }
  end
end

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
  
  if target_bid && bid_str == 'com.samvel.forma'
    ['HEALTHKIT', 'APP_GROUPS'].each do |cap|
      begin
        Spaceship::ConnectAPI::BundleIdCapability.create(
          bundle_id_id: target_bid.id,
          capability_type: cap
        )
        puts "  ✅ Enabled capability #{cap} for #{bid_str}"
      rescue => cap_err
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
    end
  end
end

# Refresh Bundle IDs & Profiles
all_bundle_ids = Spaceship::ConnectAPI::BundleId.all
all_profiles = Spaceship::ConnectAPI::Profile.all(includes: "bundleId,certificates")

# 4. Fetch or Recreate Provisioning Profiles explicitly containing active_cert_id
profiles_out_dir = "/tmp/profiles"
FileUtils.mkdir_p(profiles_out_dir)
installed_profiles_dir = File.expand_path("~/Library/MobileDevice/Provisioning Profiles")
FileUtils.mkdir_p(installed_profiles_dir)

puts "📋 Validating and synchronizing Provisioning Profiles with active certificate #{active_cert_id}..."

target_bundles.each do |bid_str, prof_name|
  target_bid = all_bundle_ids.find { |b| b.identifier == bid_str }
  matching_profiles = all_profiles.select do |p|
    p.bundle_id&.identifier == bid_str && 
    (p.profile_type.to_s.include?("APP_STORE") || p.profile_type.to_s.include?("DISTRIBUTION"))
  end
  
  # Check if any matching profile includes active_cert_id
  valid_profile = matching_profiles.find do |p|
    p.certificates&.any? { |c| c.id == active_cert_id }
  end

  # Delete outdated profiles that don't contain active_cert_id
  matching_profiles.each do |p|
    if p != valid_profile
      puts "🗑️ Deleting outdated profile #{p.name} (#{p.id}) because it lacks certificate #{active_cert_id}..."
      begin
        p.delete!
      rescue => del_err
        puts "Note on delete: #{del_err.message}"
      end
    end
  end

  # If no valid profile containing active_cert_id exists, create a fresh one
  if valid_profile.nil? && target_bid && active_cert_id
    puts "Creating fresh App Store profile for #{bid_str} containing certificate #{active_cert_id}..."
    prof_type = bid_str.include?("watch") ? "WATCHOS_APP_STORE" : "IOS_APP_STORE"
    begin
      valid_profile = Spaceship::ConnectAPI::Profile.create(
        name: prof_name,
        profile_type: prof_type,
        bundle_id_id: target_bid.id,
        certificate_ids: [active_cert_id]
      )
      puts "  ✅ Created profile #{prof_name} with cert #{active_cert_id}"
    rescue => err
      puts "  ⚠️ Note on profile create (#{prof_type}): #{err.message}. Retrying as IOS_APP_STORE..."
      begin
        valid_profile = Spaceship::ConnectAPI::Profile.create(
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

  if valid_profile
    content_b64 = valid_profile.profile_content
    if content_b64
      # Write named profile for direct CI extraction
      named_path = File.join(profiles_out_dir, "#{bid_str}.mobileprovision")
      File.binwrite(named_path, Base64.decode64(content_b64))
      
      # Write UUID profile for Xcode
      uuid_path = File.join(installed_profiles_dir, "#{valid_profile.uuid}.mobileprovision")
      File.binwrite(uuid_path, Base64.decode64(content_b64))
      puts "  ✅ Provisioning Profile verified for #{bid_str} -> #{valid_profile.name} (#{valid_profile.uuid})"
      
      if bid_str == 'com.samvel.forma' && ENV['GITHUB_ENV']
        File.open(ENV['GITHUB_ENV'], 'a') do |f|
          f.puts("PROFILE_NAME=#{valid_profile.name}")
          f.puts("PROFILE_UUID=#{valid_profile.uuid}")
        end
      end
    end
  else
    puts "  ⚠️ Warning: Could not find or create valid profile for #{bid_str}"
  end
end

puts "🎉 Provisioning and Certificate synchronization complete!"
