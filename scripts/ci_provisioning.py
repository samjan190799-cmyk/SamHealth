import os
import sys
import time
import json
import base64
import subprocess

# Auto-install dependencies if missing
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
    if not "BEGIN" in raw_key:
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
    
    # Add to keychain search list
    out = subprocess.check_output(["security", "list-keychains", "-d", "user"]).decode('utf-8')
    existing = [k.strip().replace('"', '') for k in out.split('\n') if k.strip()]
    all_kcs = [keychain_path] + [k for k in existing if k != keychain_path]
    subprocess.run(["security", "list-keychains", "-d", "user", "-s"] + all_kcs, check=False)
    print("✅ Keychain configured successfully.")

def ensure_distribution_certificate(headers, dev_team):
    # Check if we already have an Apple Distribution identity in keychain
    try:
        identities = subprocess.check_output(["security", "find-identity", "-v", "-p", "codesigning"]).decode('utf-8')
        if "Apple Distribution" in identities:
            print("✅ Existing Apple Distribution certificate found in local keychain.")
            return
    except Exception as e:
        print(f"Checking identity exception: {e}")

    print("🚀 No local Apple Distribution cert found. Creating new certificate via App Store Connect API...")
    key_path = "/tmp/dist.key"
    csr_path = "/tmp/dist.csr"
    cer_path = "/tmp/dist.cer"
    pem_path = "/tmp/dist.pem"
    p12_path = "/tmp/dist.p12"
    
    # 1. Generate RSA key & CSR
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
    
    res = requests.post("https://api.appstoreconnect.apple.com/v1/certificates", json=create_payload, headers=headers)
    print(f"Create certificate response: {res.status_code}")
    
    if res.status_code == 409 or (res.status_code >= 400 and "maximum" in res.text.lower()):
        print("⚠️ Maximum certificate limit reached on Apple Developer account. Fetching certificates to revoke oldest...")
        list_res = requests.get("https://api.appstoreconnect.apple.com/v1/certificates?filter[certificateType]=DISTRIBUTION&limit=50", headers=headers)
        if list_res.status_code == 200:
            certs = list_res.json().get('data', [])
            # Sort by expiration date ascending to revoke the oldest
            certs_sorted = sorted(certs, key=lambda c: c.get('attributes', {}).get('expirationDate', ''))
            if certs_sorted:
                oldest_id = certs_sorted[0].get('id')
                oldest_name = certs_sorted[0].get('attributes', {}).get('name')
                print(f"🗑️ Revoking oldest distribution certificate {oldest_name} (ID: {oldest_id})...")
                del_res = requests.delete(f"https://api.appstoreconnect.apple.com/v1/certificates/{oldest_id}", headers=headers)
                print(f"Revoke response: {del_res.status_code}")
                time.sleep(2)
                # Retry creation
                res = requests.post("https://api.appstoreconnect.apple.com/v1/certificates", json=create_payload, headers=headers)
                print(f"Retry create certificate response: {res.status_code}")

    if res.status_code in [200, 201]:
        cert_data = res.json().get('data', {}).get('attributes', {})
        cert_b64 = cert_data.get('certificateContent')
        with open(cer_path, 'wb') as f:
            f.write(base64.b64decode(cert_b64))
        
        # Convert DER to PEM and combine with private key to create .p12
        subprocess.run(["openssl", "x509", "-inform", "der", "-in", cer_path, "-out", pem_path], check=True)
        subprocess.run(["openssl", "pkcs12", "-export", "-inkey", key_path, "-in", pem_path, "-out", p12_path, "-passout", "pass:buildpassword", "-name", "Apple Distribution: Forma"], check=True)
        setup_keychain_with_cert(p12_path, password="buildpassword")
    else:
        print(f"❌ Failed to create certificate: {res.text}")

def fetch_and_install_profiles(headers):
    profiles_dir = os.path.expanduser('~/Library/MobileDevice/Provisioning Profiles')
    os.makedirs(profiles_dir, exist_ok=True)
    
    print("📋 Fetching and installing all Provisioning Profiles...")
    res = requests.get('https://api.appstoreconnect.apple.com/v1/profiles?limit=50', headers=headers)
    target_profile_name = None
    
    if res.status_code == 200:
        data = res.json()
        for item in data.get('data', []):
            attrs = item.get('attributes', {})
            name = attrs.get('name', '')
            uuid = attrs.get('uuid')
            p_type = attrs.get('profileType', '')
            content_b64 = attrs.get('profileContent')
            if content_b64 and uuid:
                file_path = os.path.join(profiles_dir, f"{uuid}.mobileprovision")
                with open(file_path, 'wb') as f:
                    f.write(base64.b64decode(content_b64))
                print(f"  • Profile: '{name}' ({p_type}) -> {uuid}.mobileprovision")
                if 'forma' in name.lower() and ('appstore' in p_type.lower() or 'store' in name.lower() or 'distribution' in p_type.lower()):
                    target_profile_name = name
    else:
        print(f"Profiles fetch error: {res.text}")
        
    if target_profile_name:
        print(f"🎯 Target Profile Selected: {target_profile_name}")
        github_env = os.environ.get('GITHUB_ENV')
        if github_env:
            with open(github_env, 'a') as f:
                f.write(f"PROFILE_NAME={target_profile_name}\n")

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

    # Ensure valid distribution certificate exists and is imported into keychain
    ensure_distribution_certificate(headers, dev_team)
    
    # Fetch and install provisioning profiles
    fetch_and_install_profiles(headers)

if __name__ == '__main__':
    main()
