require 'spaceship'
require 'base64'

puts "🔑 Initializing Spaceship App Store Connect API Token..."
key_id = ENV['APP_STORE_CONNECT_KEY_ID']
issuer_id = ENV['APP_STORE_CONNECT_ISSUER_ID']
key_content = ENV['APP_STORE_CONNECT_API_KEY']

if key_id.nil? || issuer_id.nil? || key_content.nil?
  puts "❌ Error: Missing credentials"
  exit 1
end

raw_key = key_content.strip
if !raw_key.include?("BEGIN")
  begin
    decoded = Base64.decode64(raw_key)
    raw_key = decoded if decoded.include?("BEGIN")
  rescue => e
    puts "Base64 decode warning: #{e.message}"
  end
end
raw_key = raw_key.gsub("\\n", "\n")

token = Spaceship::ConnectAPI::Token.create(
  key_id: key_id,
  issuer_id: issuer_id,
  key: raw_key,
  in_house: false
)
Spaceship::ConnectAPI.token = token

puts "🔍 Finding app com.samvel.forma..."
app = Spaceship::ConnectAPI::App.find("com.samvel.forma")
if app.nil?
  puts "❌ App com.samvel.forma not found!"
  exit 1
end
puts "✅ Found app: #{app.name} (ID: #{app.id})"

# 1. Update App Info (Primary Category, Subtitle & Privacy URL)
begin
  puts "\n📦 Updating App Category & AppInfo Localizations..."
  app_res = Spaceship::ConnectAPI.get_app(app_id: app.id, includes: "appInfos")
  app_info_data = app_res.body['data']['relationships']['appInfos']['data']
  if app_info_data && app_info_data.any?
    app_info_id = app_info_data.first['id']
    puts "Found AppInfo ID: #{app_info_id}"
    
    # Update Category to HEALTH_AND_FITNESS
    begin
      Spaceship::ConnectAPI.patch_app_info(
        app_info_id: app_info_id,
        primary_category_id: "HEALTH_AND_FITNESS"
      )
      puts "✅ Primary Category set to HEALTH_AND_FITNESS"
    rescue => e
      puts "⚠️ Category update notice: #{e.message}"
    end
    
    # Update Subtitle & Privacy Policy
    privacy_url = "https://samjan190799-cmyk.github.io/SamHealth/privacy.html"
    subtitle_ru = "Здоровье, спорт и привычки"
    subtitle_en = "Health, Fitness & Habits"
    
    locs_resp = Spaceship::ConnectAPI.get_app_info_localizations(app_info_id: app_info_id)
    if locs_resp && locs_resp.body && locs_resp.body['data']
      locs_resp.body['data'].each do |loc|
        loc_id = loc['id']
        locale = loc['attributes']['locale']
        sub = locale.to_s.start_with?("ru") ? subtitle_ru : subtitle_en
        begin
          Spaceship::ConnectAPI.patch_app_info_localization(
            app_info_localization_id: loc_id,
            attributes: {
              privacyPolicyUrl: privacy_url,
              subtitle: sub
            }
          )
          puts "✅ AppInfo localization updated for #{locale} (Privacy Policy: #{privacy_url}, Subtitle: #{sub})"
        rescue => e
          puts "⚠️ AppInfo error for #{locale}: #{e.message}"
        end
      end
    end
  end
rescue => e
  puts "⚠️ AppInfo error: #{e.message}"
end

# 2. Update Version Metadata (Description, Keywords, URLs, Promo)
begin
  puts "\n📝 Updating App Store Version Metadata..."
  versions = app.get_app_store_versions
  target_version = versions.find { |v| ["PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED"].include?(v.app_store_state) } || versions.first
  
  if target_version
    puts "🎯 Target version: #{target_version.version_string} (ID: #{target_version.id}, State: #{target_version.app_store_state})"
    
    desc_text = <<~DESC
      Forma — ваш персональный умный трекер активности, здоровья и физической формы с поддержкой ИИ-коуча и Apple Watch.

      ГЛАВНЫЕ ВОЗМОЖНОСТИ:
      * Персональный ИИ-коуч: умный анализ питания по фото, индивидуальные советы по восстановлению и режиму тренировок.
      * 35 режимов тренировок на Apple Watch: непрерывный замер пульса высокой частоты, учет калорий по стандарту MET, автоподсчет повторений и закрытие системных колец активности.
      * Умная гидратация и трекер кофеина: динамический расчет нормы воды, прогноз «Окна глубокого сна» с учетом кинетики выведения кофеина, интерактивный стакан и виджеты Dynamic Island.
      * Синхронизация с Apple Health: автоматический учет шагов, активных калорий, вариабельности пульса (HRV) и сна.
      * Интерактивные виджеты: прогресс дня, шагомер и водный баланс прямо на экране «Домой» и экране блокировки.

      Конфиденциальность превыше всего: ваши данные о здоровье хранятся на вашем устройстве и в личном хранилище Apple HealthKit.

      Медицинский дисклеймер: Forma не является медицинским изделием и не заменяет консультацию квалифицированного врача. Перед изменением диеты или тренировочного плана проконсультируйтесь с врачом.

      Условия использования (Standard Apple EULA):
      https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

      Политика конфиденциальности:
      https://samjan190799-cmyk.github.io/SamHealth/privacy.html
    DESC

    keywords = "трекер,здоровье,фитнес,тренировки,шагомер,вода,кофеин,пульс,калории,apple watch,сон,ии коуч,диета"
    promo = "Персональный умный трекер здоровья, 35 тренировок на Apple Watch, адаптивная гидратация и ИИ-коуч в одном приложении."
    support_url = "https://samjan190799-cmyk.github.io/SamHealth/"
    marketing_url = "https://samjan190799-cmyk.github.io/SamHealth/"
    
    vlocs = target_version.get_app_store_version_localizations
    vlocs.each do |vloc|
      begin
        Spaceship::ConnectAPI.patch_app_store_version_localization(
          app_store_version_localization_id: vloc.id,
          attributes: {
            description: desc_text.strip,
            keywords: keywords,
            promotionalText: promo,
            supportUrl: support_url,
            marketingUrl: marketing_url
          }
        )
        puts "✅ Version localization updated for #{vloc.locale} (Description, Keywords, URLs, Promo)!"
      rescue => e
        puts "⚠️ Version localization error for #{vloc.locale}: #{e.message}"
      end
    end
    
    # 3. Upload Converted Screenshots (1290x2796)
    begin
      puts "\n📸 Uploading App Store Screenshots (1290x2796) in logical sequence..."
      screenshot_files = [
        { path: "screenshots/1_home.png", title: "1. Главный экран (Forma, ИИ-тренер, XP)" },
        { path: "screenshots/2_workouts.png", title: "2. 35 тренировок и Apple Health" },
        { path: "screenshots/3_nutrition.png", title: "3. Питание и динамика веса" },
        { path: "screenshots/4_habits.png", title: "4. Привычки и дисциплина" },
        { path: "screenshots/5_settings.png", title: "5. Профиль и Forma PRO" }
      ]
      
      vlocs.each do |vloc|
        puts "Processing screenshot set for locale: #{vloc.locale}..."
        sets = vloc.get_app_screenshot_sets || []
        set = sets.find { |s| s.screenshot_display_type == "APP_IPHONE_67" }
        
        if set.nil?
          puts "Creating new screenshot set for APP_IPHONE_67..."
          begin
            resp = Spaceship::ConnectAPI.post_app_screenshot_set(
              app_store_version_localization_id: vloc.id,
              attributes: { screenshotDisplayType: "APP_IPHONE_67" }
            )
            set = resp.to_models.first if resp.respond_to?(:to_models)
          rescue => e
            puts "⚠️ Create screenshot set error: #{e.message}"
          end
        end
        
        if set
          # Delete existing screenshots if any to avoid duplication
          begin
            existing = set.app_screenshots || []
            if existing.any?
              puts "Cleaning up #{existing.count} older screenshots..."
              existing.each(&:delete!)
            end
          rescue => e
            puts "⚠️ Existing screenshots cleanup note: #{e.message}"
          end
          
          screenshot_files.each_with_index do |item, idx|
            f_path = item[:path]
            f_title = item[:title]
            if File.exist?(f_path)
              puts "🚀 [#{idx+1}/#{screenshot_files.count}] Uploading #{f_title} (#{f_path})..."
              begin
                set.upload_screenshot(path: f_path, wait_for_processing: true)
                puts "✅ Successfully uploaded #{f_title}!"
              rescue => e
                puts "⚠️ Upload error for #{f_path}: #{e.message}"
              end
            else
              puts "⚠️ File not found: #{f_path}"
            end
          end
        end
      end
    rescue => e
      puts "⚠️ Screenshot block error: #{e.message}"
    end
    
    # 4. Update Review Details
    begin
      puts "\n🕵️ Updating App Store Review Notes..."
      rev_resp = Spaceship::ConnectAPI.get_app_store_review_detail(app_store_version_id: target_version.id)
      if rev_resp && rev_resp.body && rev_resp.body['data']
        review_notes = <<~NOTES
          Hello App Review Team,

          This submission addresses all previously identified points:

          1. Guideline 2.1(b) (In-App Purchases):
          All in-app purchases and auto-renewable subscriptions (com.samvel.forma.pro.yearly, com.samvel.forma.pro.monthly, com.samvel.forma.pro.lifetime) have been submitted with review screenshots attached. All purchases can be fully tested in the Sandbox environment.

          2. Guideline 1.4.1 (Medical Citations & Sources):
          The app includes a dedicated "Scientific Methodology & Citations" screen (accessible from Settings, Paywall, and Health metrics cards) citing peer-reviewed sources with direct links (Task Force Circulation 1996 for HRV, AHA/ACSM for VO2 Max, EFSA/NAM for caffeine and hydration kinetics, Mifflin-St Jeor for BMR). Clear medical disclaimers are prominent on all health calculation screens.

          3. Guidelines 5.1.1(i) & 5.1.2(i) (Third-Party AI Transparency & Consent):
          The app obtains explicit user permission via an in-app consent sheet before transmitting any query or food photo to Google Gemini API (Google LLC). The prompt details exactly what data is sent (anonymized photo/prompt only, no personal identifiers, no location), who it is sent to (Google LLC via TLS/HTTPS), and confirms equal privacy protection without training or advertising usage. Users can toggle or revoke this anytime in Settings.

          4. Guideline 3.1.2(c) (Subscriptions & EULA):
          A functional link to Apple's standard Terms of Use (EULA) and Privacy Policy has been added directly to the App Description metadata, and complete auto-renewal disclosure terms are displayed on the in-app Paywall.

          No login/demo account is required. The app operates locally with Apple HealthKit.
        NOTES

        Spaceship::ConnectAPI.patch_app_store_review_detail(
          app_store_review_detail_id: rev_id,
          attributes: {
            notes: review_notes.strip,
            demoAccountRequired: false
          }
        )
        puts "✅ Review notes & demo account flag updated successfully!"
      end
    rescue => e
      puts "⚠️ Review detail error: #{e.message}"
    end
  end
rescue => e
  puts "⚠️ Version metadata error: #{e.message}"
end

puts "\n🎉 Готово! Все доступные метаданные и скриншоты успешно синхронизированы в App Store Connect!"
