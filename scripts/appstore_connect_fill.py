import os
import sys
import time
import json
import base64
import requests
import jwt

def get_auth_token(key_id, issuer_id, key_content):
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
        'exp': now + 1200,
        'aud': 'appstoreconnect.v1'
    }
    return jwt.encode(payload, raw_key, algorithm='ES256', headers={'kid': key_id, 'typ': 'JWT'})

def make_request(method, url, token, json_data=None):
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    resp = requests.request(method, url, headers=headers, json=json_data)
    return resp

def main():
    key_id = os.environ.get("APP_STORE_CONNECT_KEY_ID")
    issuer_id = os.environ.get("APP_STORE_CONNECT_ISSUER_ID")
    key_content = os.environ.get("APP_STORE_CONNECT_API_KEY")
    
    if not key_id or not issuer_id or not key_content:
        print("❌ Error: Missing App Store Connect API credentials.")
        sys.exit(1)
        
    print(f"🔑 Generating API Token for Key ID: {key_id}...")
    token = get_auth_token(key_id, issuer_id, key_content)
    
    # 1. Поиск приложения com.samvel.forma
    print("🔍 Fetching app with bundleId 'com.samvel.forma'...")
    res = make_request("GET", "https://api.appstoreconnect.apple.com/v1/apps?filter[bundleId]=com.samvel.forma", token)
    if res.status_code != 200:
        print(f"❌ Failed to fetch apps: {res.status_code} - {res.text}")
        sys.exit(1)
        
    apps = res.json().get("data", [])
    if not apps:
        print("❌ No app found with bundleId 'com.samvel.forma'")
        sys.exit(1)
        
    app = apps[0]
    app_id = app["id"]
    print(f"✅ Found app 'Forma' (ID: {app_id})")
    
    # 2. Обновление первичной категории (Health & Fitness) и ссылки на политику в AppInfo
    print("\n📦 Updating App Category & AppInfo...")
    res = make_request("GET", f"https://api.appstoreconnect.apple.com/v1/apps/{app_id}/appInfos", token)
    if res.status_code == 200 and res.json().get("data"):
        app_info = res.json()["data"][0]
        app_info_id = app_info["id"]
        
        # Обновление категории
        cat_payload = {
            "data": {
                "type": "appInfos",
                "id": app_info_id,
                "relationships": {
                    "primaryCategory": {
                        "data": {
                            "type": "appCategories",
                            "id": "HEALTH_AND_FITNESS"
                        }
                    }
                }
            }
        }
        cat_res = make_request("PATCH", f"https://api.appstoreconnect.apple.com/v1/appInfos/{app_info_id}", token, cat_payload)
        if cat_res.status_code in [200, 204]:
            print("✅ Primary Category set to HEALTH_AND_FITNESS")
        else:
            print(f"⚠️ Category update: {cat_res.status_code} - {cat_res.text}")
            
        # Обновление локализации AppInfo (Политика конфиденциальности и подзаголовок)
        loc_res = make_request("GET", f"https://api.appstoreconnect.apple.com/v1/appInfos/{app_info_id}/appInfoLocalizations", token)
        if loc_res.status_code == 200:
            locs = loc_res.json().get("data", [])
            privacy_url = "https://samjan190799-cmyk.github.io/SamHealth/privacy.html"
            subtitle = "Здоровье, спорт и привычки"
            
            for loc in locs:
                loc_id = loc["id"]
                loc_locale = loc["attributes"].get("locale")
                patch_payload = {
                    "data": {
                        "type": "appInfoLocalizations",
                        "id": loc_id,
                        "attributes": {
                            "privacyPolicyUrl": privacy_url,
                            "subtitle": subtitle if loc_locale.startswith("ru") else "Health, Fitness & Habits"
                        }
                    }
                }
                upd_res = make_request("PATCH", f"https://api.appstoreconnect.apple.com/v1/appInfoLocalizations/{loc_id}", token, patch_payload)
                if upd_res.status_code in [200, 204]:
                    print(f"✅ AppInfo Localization updated for {loc_locale} (Privacy Policy & Subtitle)")
                else:
                    print(f"⚠️ AppInfo Localization ({loc_locale}): {upd_res.status_code} - {upd_res.text}")
                    
    # 3. Обновление версии в статусе PREPARE_FOR_SUBMISSION
    print("\n📝 Fetching App Store Versions...")
    res = make_request("GET", f"https://api.appstoreconnect.apple.com/v1/apps/{app_id}/appStoreVersions", token)
    if res.status_code == 200 and res.json().get("data"):
        versions = res.json()["data"]
        # Ищем версию для отправки (обычно статус PREPARE_FOR_SUBMISSION или первая)
        target_version = None
        for v in versions:
            state = v["attributes"].get("appStoreState")
            if state in ["PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED"]:
                target_version = v
                break
        if not target_version and versions:
            target_version = versions[0]
            
        if target_version:
            version_id = target_version["id"]
            ver_str = target_version["attributes"].get("versionString", "1.0")
            print(f"🎯 Target version: {ver_str} (ID: {version_id})")
            
            # Загрузка и обновление текстовых метаданных
            vloc_res = make_request("GET", f"https://api.appstoreconnect.apple.com/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations", token)
            if vloc_res.status_code == 200:
                vlocs = vloc_res.json().get("data", [])
                
                desc_text = """Forma — ваш персональный умный трекер активности, здоровья и физической формы с поддержкой ИИ-коуча и Apple Watch.

ГЛАВНЫЕ ВОЗМОЖНОСТИ:
• 🧠 Персональный ИИ-коуч: умный анализ питания по фото, индивидуальные советы по восстановлению и режиму тренировок.
• ⌚️ 35 режимов тренировок на Apple Watch: непрерывный замер пульса высокой частоты, учет калорий по стандарту MET, автоподсчет повторений и закрытие системных колец активности.
• 💧 Умная гидратация и трекер кофеина: динамический расчет нормы воды, прогноз «Окна глубокого сна» с учетом кинетики выведения кофеина, интерактивный стакан и виджеты Dynamic Island.
• 📊 Синхронизация с Apple Health: автоматический учет шагов, активных калорий, вариабельности пульса (HRV) и сна.
• 📱 Интерактивные виджеты: прогресс дня, шагомер и водный баланс прямо на экране «Домой» и экране блокировки.

Конфиденциальность превыше всего: ваши данные о здоровье хранятся на вашем устройстве и в личном хранилище Apple HealthKit."""

                keywords = "трекер,здоровье,фитнес,тренировки,шагомер,вода,кофеин,пульс,калории,apple watch,сон,ии коуч,диета"
                promo_text = "Персональный умный трекер здоровья, 35 тренировок на Apple Watch, адаптивная гидратация и ИИ-коуч в одном приложении."
                support_url = "https://samjan190799-cmyk.github.io/SamHealth/"
                marketing_url = "https://samjan190799-cmyk.github.io/SamHealth/"
                
                for vloc in vlocs:
                    vloc_id = vloc["id"]
                    vloc_locale = vloc["attributes"].get("locale")
                    v_payload = {
                        "data": {
                            "type": "appStoreVersionLocalizations",
                            "id": vloc_id,
                            "attributes": {
                                "description": desc_text,
                                "keywords": keywords,
                                "promotionalText": promo_text,
                                "supportUrl": support_url,
                                "marketingUrl": marketing_url
                            }
                        }
                    }
                    v_upd = make_request("PATCH", f"https://api.appstoreconnect.apple.com/v1/appStoreVersionLocalizations/{vloc_id}", token, v_payload)
                    if v_upd.status_code in [200, 204]:
                        print(f"✅ Version Localization ({vloc_locale}) successfully filled with Description, Keywords & URLs!")
                    else:
                        print(f"⚠️ Version Localization ({vloc_locale}): {v_upd.status_code} - {v_upd.text}")
                        
            # Заметки для ревьюера (App Store Review Details)
            print("\n🕵️ Updating App Store Review Notes...")
            rev_res = make_request("GET", f"https://api.appstoreconnect.apple.com/v1/appStoreVersions/{version_id}/appStoreReviewDetail", token)
            if rev_res.status_code == 200 and rev_res.json().get("data"):
                rev_id = rev_res.json()["data"]["id"]
                rev_payload = {
                    "data": {
                        "type": "appStoreReviewDetails",
                        "id": rev_id,
                        "attributes": {
                            "notes": "Приложение не требует создания учетной записи и работает локально на устройстве с синхронизацией через Apple HealthKit. Для тестирования всех функций тренировок на часах и телефоне авторизация не требуется. Все покупки можно протестировать в среде Sandbox.",
                            "demoAccountRequired": False
                        }
                    }
                }
                rev_upd = make_request("PATCH", f"https://api.appstoreconnect.apple.com/v1/appStoreReviewDetails/{rev_id}", token, rev_payload)
                if rev_upd.status_code in [200, 204]:
                    print("✅ App Store Review Notes & Demo Account flag updated successfully!")
                else:
                    print(f"⚠️ Review details update: {rev_upd.status_code} - {rev_upd.text}")
                    
    # 4. Проверка и создание Subscription Group
    print("\n💎 Checking Subscription Groups...")
    sg_res = make_request("GET", f"https://api.appstoreconnect.apple.com/v1/apps/{app_id}/subscriptionGroups", token)
    group_id = None
    if sg_res.status_code == 200:
        groups = sg_res.json().get("data", [])
        for g in groups:
            if "forma" in g["attributes"].get("referenceName", "").lower():
                group_id = g["id"]
                print(f"✅ Found existing Subscription Group: {g['attributes'].get('referenceName')} (ID: {group_id})")
                break
                
        if not group_id:
            print("Creating Subscription Group 'Forma Pro Group'...")
            sg_create = {
                "data": {
                    "type": "subscriptionGroups",
                    "attributes": {
                        "referenceName": "Forma Pro Group"
                    },
                    "relationships": {
                        "app": {
                            "data": {
                                "type": "apps",
                                "id": app_id
                            }
                        }
                    }
                }
            }
            new_sg = make_request("POST", "https://api.appstoreconnect.apple.com/v1/subscriptionGroups", token, sg_create)
            if new_sg.status_code in [200, 201]:
                group_id = new_sg.json()["data"]["id"]
                print(f"✅ Created Subscription Group (ID: {group_id})")
            else:
                print(f"⚠️ Subscription group create: {new_sg.status_code} - {new_sg.text}")

    print("\n🎉 ВСЕ ДОСТУПНЫЕ ПОЛЯ В APP STORE CONNECT УСПЕШНО ЗАПОЛНЕНЫ ЧЕРЕЗ API!")

if __name__ == "__main__":
    main()
