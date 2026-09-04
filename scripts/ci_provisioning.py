import os
import sys
import time
import json
import base64
import subprocess

try:
    import requests
    import jwt
except ImportError:
    subprocess.run([sys.executable, "-m", "pip", "install", "--quiet", "pyjwt", "cryptography", "requests", "--break-system-packages"], check=False)
    subprocess.run(["pip3", "install", "--quiet", "pyjwt", "cryptography", "requests"], check=False)
    import requests
    import jwt

def get_auth_token(key_id, issuer_id, key_content):
    if not key_content:
        raise ValueError("App Store Connect API Key is missing")
    
    raw_key = key_content.strip()
    if "BEGIN" not in raw_key:
        try:
            decoded = base64.b64decode(raw_key).decode('utf-8')
            if "BEGIN" in decoded:
                raw_key = decoded
        except Exception:
            pass
            
    if "\\n" in raw_key:
        raw_key = raw_key.replace("\\n", "\n")
        
    now = int(time.time())
    payload = {
        'iss': issuer_id,
        'iat': now - 20,
        'exp': now + 1000,
        'aud': 'appstoreconnect.v1'
    }
    token = jwt.encode(payload, raw_key, algorithm='ES256', headers={'kid': key_id, 'typ': 'JWT'})
    return token

def setup_keychain_with_cert(p12_path, password="buildpassword"):
    keychain_path = "/tmp/build.keychain"
    print(f"🔑 Setting up keychain at {keychain_path}...")
    subprocess.run(["security", "create-keychain", "-p", password, keychain_path], check=False)
    subprocess.run(["security", "set-keychain-settings", "-lut", "21600", keychain_path], check=False)
    subprocess.run(["security", "unlock-keychain", "-p", password, keychain_path], check=False)
    subprocess.run(["security", "import", p12_path, "-k", keychain_path, "-P", password, "-T", "/usr/bin/codesign", "-T", "/usr/bin/security"], check=False)
    subprocess.run(["security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:", "-s", "-k", password, keychain_path], check=False)
    
    for url in [
        "https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer",
        "https://www.apple.com/certificateauthority/AppleWWDRCAG6.cer",
        "https://www.apple.com/appleca/AppleIncRootCertificate.cer"
    ]:
        fname = url.split("/")[-1]
        subprocess.run(f"curl -s -f -L '{url}' -o '/tmp/{fname}' && security import '/tmp/{fname}' -k {keychain_path} -T /usr/bin/codesign -T /usr/bin/security", shell=True, check=False)
        
    out = subprocess.check_output(["security", "list-keychains", "-d", "user"]).decode('utf-8')
    existing = [k.strip().replace('"', '') for k in out.split('\n') if k.strip()]
    all_kcs = [keychain_path] + [k for k in existing if k != keychain_path]
    subprocess.run(["security", "list-keychains", "-d", "user", "-s"] + all_kcs, check=False)
    print("✅ Keychain configured successfully.")

def ensure_distribution_certificate(headers, dev_team):
    key_path = "/tmp/dist.key"
    csr_path = "/tmp/dist.csr"
    cer_path = "/tmp/dist.cer"
    pem_path = "/tmp/dist.pem"
    p12_path = "/tmp/dist.p12"
    
    subprocess.run(["openssl", "genrsa", "-out", key_path, "2048"], check=True)
    subprocess.run(["openssl", "req", "-new", "-key", key_path, "-out", csr_path, "-subj", f"/CN=Apple Distribution: Forma/O={dev_team}"], check=True)
    with open(csr_path, 'r') as f:
        csr_content = f.read()

    create_payload = {
        "data": {
            "type": "certificates",
            "attributes": {
                "certificateType": "DISTRIBUTION",
                "csrContent": csr_content
            }
        }
    }
    
    cert_id = None
    max_attempts = 5
    attempt = 0
    res = None
    
    while attempt < max_attempts and cert_id is None:
        attempt += 1
        print(f"🚀 Attempt {attempt}/{max_attempts} to create paired distribution certificate...")
        res = requests.post("https://api.appstoreconnect.apple.com/v1/certificates", json=create_payload, headers=headers)
        if res.status_code in [200, 201]:
            cert_node = res.json().get('data', {})
            cert_id = cert_node.get('id')
            print(f"✅ Created fresh distribution certificate ID: {cert_id}")
            break
        else:
            print(f"⚠️ Certificate create response (attempt {attempt}): {res.status_code} {res.text}")
            list_res = requests.get("https://api.appstoreconnect.apple.com/v1/certificates?filter[certificateType]=DISTRIBUTION&limit=50", headers=headers)
            if list_res.status_code == 200:
                certs = list_res.json().get('data', [])
                certs_sorted = sorted(certs, key=lambda c: c.get('attributes', {}).get('expirationDate', ''))
                if certs_sorted:
                    oldest_id = certs_sorted[0].get('id')
                    print(f"🗑️ Revoking oldest certificate {oldest_id}...")
                    requests.delete(f"https://api.appstoreconnect.apple.com/v1/certificates/{oldest_id}", headers=headers)
                    time.sleep(4)
                else:
                    time.sleep(3)
            else:
                time.sleep(3)

    if not cert_id:
        print("❌ CRITICAL: Failed to create paired distribution certificate!")
        sys.exit(1)

    cert_node = res.json().get('data', {})
    cert_id = cert_node.get('id')
    cert_data = cert_node.get('attributes', {})
    cert_b64 = cert_data.get('certificateContent')
    with open(cer_path, 'wb') as f:
        f.write(base64.b64decode(cert_b64))
    
    subprocess.run(["openssl", "x509", "-inform", "der", "-in", cer_path, "-out", pem_path], check=True)
    subprocess.run(["openssl", "pkcs12", "-export", "-inkey", key_path, "-in", pem_path, "-out", p12_path, "-passout", "pass:buildpassword", "-name", "Apple Distribution: Forma"], check=True)
    setup_keychain_with_cert(p12_path, password="buildpassword")
    
    # Extract SHA-1 Fingerprint
    raw_fp = subprocess.check_output(["openssl", "x509", "-inform", "der", "-in", cer_path, "-noout", "-fingerprint", "-sha1"]).decode('utf-8')
    sha1 = raw_fp.split('=')[-1].strip().replace(':', '')
    print(f"🎯 Distribution SHA-1 Fingerprint: {sha1}")
    with open("/tmp/signing_identity.txt", "w") as f:
        f.write(sha1)
    github_env = os.environ.get('GITHUB_ENV')
    if github_env:
        with open(github_env, 'a') as f:
            f.write(f"SIGNING_IDENTITY={sha1}\n")

    return cert_id

def ensure_bundle_ids_and_profiles(headers, cert_id):
    profiles_out_dir = "/tmp/profiles"
    os.makedirs(profiles_out_dir, exist_ok=True)
    installed_profiles_dir = os.path.expanduser('~/Library/MobileDevice/Provisioning Profiles')
    os.makedirs(installed_profiles_dir, exist_ok=True)

    targets = {
        'com.samvel.forma': 'Forma AppStore',
        'com.samvel.forma.widgets': 'Forma Widgets AppStore',
        'com.samvel.forma.watchkitapp': 'Forma Watch AppStore'
    }

    # 1. Fetch Bundle IDs
    bids_res = requests.get('https://api.appstoreconnect.apple.com/v1/bundleIds?limit=100', headers=headers)
    existing_bids = {}
    if bids_res.status_code == 200:
        for b in bids_res.json().get('data', []):
            existing_bids[b['attributes']['identifier']] = b['id']

    for bid_str, prof_name in targets.items():
        if bid_str not in existing_bids:
            print(f"Creating Bundle ID for {bid_str}...")
            c_res = requests.post('https://api.appstoreconnect.apple.com/v1/bundleIds', json={
                "data": {
                    "type": "bundleIds",
                    "attributes": {
                        "identifier": bid_str,
                        "name": prof_name.replace(" AppStore", ""),
                        "platform": "UNIVERSAL"
                    }
                }
            }, headers=headers)
            if c_res.status_code in [200, 201]:
                existing_bids[bid_str] = c_res.json()['data']['id']

    # 1.1 Enable Capabilities for Bundle IDs
    for bid_str, prof_name in targets.items():
        bid_id = existing_bids.get(bid_str)
        if bid_id:
            caps = []
            if bid_str == 'com.samvel.forma':
                caps = ['HEALTHKIT', 'APP_GROUPS']
            elif bid_str == 'com.samvel.forma.widgets':
                caps = ['APP_GROUPS']
            elif bid_str == 'com.samvel.forma.watchkitapp':
                caps = ['HEALTHKIT']
            for cap in caps:
                requests.post('https://api.appstoreconnect.apple.com/v1/bundleIdCapabilities', json={
                    "data": {
                        "type": "bundleIdCapabilities",
                        "attributes": {"capabilityType": cap},
                        "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bid_id}}}
                    }
                }, headers=headers)

    # 2. Fetch Profiles with certificates relationship
    prof_res = requests.get('https://api.appstoreconnect.apple.com/v1/profiles?include=bundleId,certificates&limit=100', headers=headers)
    if prof_res.status_code == 200:
        all_profiles = prof_res.json().get('data', [])
        for bid_str, prof_name in targets.items():
            bid_id = existing_bids.get(bid_str)
            if not bid_id:
                continue

            matching_for_bid = [
                p for p in all_profiles 
                if p.get('relationships', {}).get('bundleId', {}).get('data', {}).get('id') == bid_id
                and ('STORE' in p.get('attributes', {}).get('profileType', '') or 'DISTRIBUTION' in p.get('attributes', {}).get('profileType', ''))
            ]

            valid_profile = None
            for p in matching_for_bid:
                cert_refs = p.get('relationships', {}).get('certificates', {}).get('data', [])
                if any(c.get('id') == cert_id for c in cert_refs):
                    valid_profile = p
                else:
                    # Delete outdated profile lacking active cert
                    p_id = p.get('id')
                    print(f"Deleting outdated profile {p.get('attributes', {}).get('name')} ({p_id})...")
                    requests.delete(f"https://api.appstoreconnect.apple.com/v1/profiles/{p_id}", headers=headers)

            if not valid_profile and cert_id:
                print(f"Creating fresh Provisioning Profile for {bid_str} with certificate {cert_id}...")
                p_type = "WATCHOS_APP_STORE" if "watch" in bid_str else "IOS_APP_STORE"
                create_p = requests.post('https://api.appstoreconnect.apple.com/v1/profiles', json={
                    "data": {
                        "type": "profiles",
                        "attributes": {
                            "name": prof_name,
                            "profileType": p_type
                        },
                        "relationships": {
                            "bundleId": {"data": {"type": "bundleIds", "id": bid_id}},
                            "certificates": {"data": [{"type": "certificates", "id": cert_id}]}
                        }
                    }
                }, headers=headers)
                if create_p.status_code in [200, 201]:
                    valid_profile = create_p.json().get('data')

            if valid_profile:
                attrs = valid_profile.get('attributes', {})
                content_b64 = attrs.get('profileContent')
                uuid = attrs.get('uuid')
                name = attrs.get('name')
                if content_b64:
                    with open(os.path.join(profiles_out_dir, f"{bid_str}.mobileprovision"), 'wb') as f:
                        f.write(base64.b64decode(content_b64))
                    with open(os.path.join(installed_profiles_dir, f"{uuid}.mobileprovision"), 'wb') as f:
                        f.write(base64.b64decode(content_b64))
                    print(f"  ✅ Profile ready for {bid_str} -> {name} ({uuid})")
                    if bid_str == 'com.samvel.forma':
                        github_env = os.environ.get('GITHUB_ENV')
                        if github_env:
                            with open(github_env, 'a') as f:
                                f.write(f"PROFILE_NAME={name}\n")
                                f.write(f"PROFILE_UUID={uuid}\n")

def main():
    key_id = os.environ.get('APP_STORE_CONNECT_KEY_ID')
    issuer_id = os.environ.get('APP_STORE_CONNECT_ISSUER_ID')
    dev_team = os.environ.get('DEV_TEAM', 'V7J345DY58')
    api_key_path = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{key_id}.p8")
    
    if os.path.exists(api_key_path):
        with open(api_key_path, 'r') as f:
            api_key_content = f.read()
    else:
        api_key_content = os.environ.get('APP_STORE_CONNECT_API_KEY', '')

    print("🔐 Authenticating with App Store Connect API...")
    token = get_auth_token(key_id, issuer_id, api_key_content)
    headers = {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    }

    cert_id = ensure_distribution_certificate(headers, dev_team)
    ensure_bundle_ids_and_profiles(headers, cert_id)

if __name__ == '__main__':
    main()
