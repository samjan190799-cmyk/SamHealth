import SwiftUI
import AVFoundation

public enum AICoachGender: String, Codable {
    case male
    case female
}

public enum AICoachID: String, CaseIterable, Identifiable, Codable {
    case alex
    case max
    case mark
    case elena
    case sofia
    case victoria
    
    public var id: String { self.rawValue }
}

public struct AICoachPersona: Identifiable, Hashable {
    public let id: AICoachID
    public let name: String
    public let specialty: String
    public let shortBio: String
    public let tagline: String
    public let gender: AICoachGender
    public let avatarAssetName: String
    public let accentColor: Color
    public let badgeEmoji: String
    
    // Системная инструкция для LLM
    public let systemPromptStyle: String
    
    // Параметры озвучки
    public let voicePitch: Float
    public let voiceRate: Float
    
    public func localizedGreeting(lang: String) -> String {
        switch id {
        case .alex:
            switch lang {
            case "en": return "Hi! I'm Coach Alex. Let's build strength and improve your technique today!"
            case "hy": return "Ողջույն! Ես մարզիչ Ալեքսն եմ: Եկ սկսենք մարզումը և բարելավենք տեխնիկան:"
            default: return "Привет! Я тренер Алекс. Держи ровный темп, правильное дыхание и давай выложимся на максимум!"
            }
        case .max:
            switch lang {
            case "en": return "Max is here! No excuses, high intensity, push your absolute limits!"
            case "hy": return "Ես Մաքսն եմ: Ոչ մի արդարացում, աշխատում ենք մինչև վերջ:"
            default: return "На связи Макс! Никаких оправданий и лени — сегодня работаем на пределе возможностей. Вперед!"
            }
        case .mark:
            switch lang {
            case "en": return "Hello! I'm Coach Mark. Discipline is key. Stay focused, stay consistent."
            case "hy": return "Բարև! Ես մարզիչ Մարկն եմ: Կարգապահությունը հաղթանակի գրավականն է:"
            default: return "Привет! Я тренер Марк. Дисциплина и осознанность важнее сиюминутного порыва. Сфокусируйся на процессе."
            }
        case .elena:
            switch lang {
            case "en": return "Hi! I'm Coach Elena. Let's sculpt your body, boost your energy, and feel amazing!"
            case "hy": return "Ողջույն! Ես մարզիչ Ելենան եմ: Եկ լիցքավորվենք էներգիայով և մարզվենք հաճույքով:"
            default: return "Привет! Я тренер Елена. Готова зарядить тебя бешеной энергией и сделать тело подтянутым и рельефным!"
            }
        case .sofia:
            switch lang {
            case "en": return "Welcome! I'm Coach Sofia. Breathe deeply, feel your body, and move with grace."
            case "hy": return "Բարի գալուստ! Ես մարզիչ Սոֆյան եմ: Խորը շնչիր, զգա մարմինդ և ձգվիր:"
            default: return "Здравствуй! Я тренер София. Сделай глубокий вдох, почувствуй свое тело и двигайся плавно и бережно к суставам."
            }
        case .victoria:
            switch lang {
            case "en": return "Hey there! I'm Coach Victoria. Find your rhythm, own your pace, and let's crush this cardio!"
            case "hy": return "Ողջույն! Ես մարզիչ Վիկտորիան եմ: Գտիր քո տեմպը և վազենք միասին:"
            default: return "Привет! Я тренер Виктория. Поймай свой ритм бега, контролируй пульс и покажи всё, на что способен твой кардио-потенциал!"
            }
        }
    }
}

@MainActor
public final class AICoachManager: ObservableObject {
    public static let shared = AICoachManager()
    
    @AppStorage("selected_coach_id") public var selectedCoachIdString: String = "alex" {
        didSet {
            objectWillChange.send()
        }
    }
    
    public let allCoaches: [AICoachPersona] = [
        // 1. Алекс (Alex)
        AICoachPersona(
            id: .alex,
            name: "Алекс",
            specialty: "Силовой тренинг и биомеханика",
            shortBio: "Универсальный атлет. Фокус на правильной технике базовых упражнений, безопасности суставов и прогрессивной нагрузке.",
            tagline: "«Сила в правильной технике»",
            gender: .male,
            avatarAssetName: "CoachAlexAvatar",
            accentColor: Color(red: 50/255, green: 215/255, blue: 75/255),
            badgeEmoji: "⚡",
            systemPromptStyle: "Ты тренер Алекс — эксперт по силовым тренировкам, биомеханике и мышечному росту. Твой тон: поддерживающий, авторитетный, энергичный, четкий.",
            voicePitch: 1.02,
            voiceRate: 0.52
        ),
        
        // 2. Макс (Max)
        AICoachPersona(
            id: .max,
            name: "Макс",
            specialty: "Hardcore & Crossfit",
            shortBio: "Бескомпромиссный наставник. Высокая интенсивность, взрывная сила, функциональный кроссфит и преодоление пределов.",
            tagline: "«Никаких оправданий, только результат»",
            gender: .male,
            avatarAssetName: "CoachMaxAvatar",
            accentColor: Color(red: 255/255, green: 69/255, blue: 58/255),
            badgeEmoji: "🥊",
            systemPromptStyle: "Ты тренер Макс — брутальный кроссфит-наставник и сержант. Твой тон: мощный, боевой, драйвовый, мотивирующий выкладываться на 100% без жалости к себе.",
            voicePitch: 0.92,
            voiceRate: 0.53
        ),
        
        // 3. Марк (Mark)
        AICoachPersona(
            id: .mark,
            name: "Марк",
            specialty: "Дисциплина и выносливость",
            shortBio: "Эксперт по ментальной стойкости, долгосрочным привычкам, контролю стресса и умной адаптации тренировок.",
            tagline: "«Дисциплина побеждает мотивацию»",
            gender: .male,
            avatarAssetName: "CoachMarkAvatar",
            accentColor: Color(red: 0/255, green: 229/255, blue: 255/255),
            badgeEmoji: "🧠",
            systemPromptStyle: "Ты тренер Марк — наставник по дисциплине, спортивной психологии и восстановлению. Твой тон: уверенный, спокойный, глубокий, стратегический.",
            voicePitch: 0.98,
            voiceRate: 0.50
        ),
        
        // 4. Елена (Elena)
        AICoachPersona(
            id: .elena,
            name: "Елена",
            specialty: "Функциональный фитнес и рельеф",
            shortBio: "Элитный фитнес-коуч. Программы для стройности, осанки, тонуса мышц и мощного заряда позитивной энергии.",
            tagline: "«Красивое тело и неиссякаемая энергия»",
            gender: .female,
            avatarAssetName: "CoachElenaAvatar",
            accentColor: Color(red: 255/255, green: 45/255, blue: 85/255),
            badgeEmoji: "🔥",
            systemPromptStyle: "Ты тренер Елена — харизматичный фитнес-коуч. Твой тон: вдохновляющий, яркий, позитивный, фокусирующийся на тонусе, осанке и красивом рельефе.",
            voicePitch: 1.15,
            voiceRate: 0.52
        ),
        
        // 5. София (Sofia)
        AICoachPersona(
            id: .sofia,
            name: "София",
            specialty: "Йога, пилатес и гибкость",
            shortBio: "Мастер мягких практик. Мобильность суставов, растяжка, снятие напряжения со спины и осознанное дыхание.",
            tagline: "«Гармония движения и внутренний баланс»",
            gender: .female,
            avatarAssetName: "CoachSofiaAvatar",
            accentColor: Color(red: 168/255, green: 85/255, blue: 247/255),
            badgeEmoji: "🧘‍♀️",
            systemPromptStyle: "Ты тренер София — мастер йоги, пилатеса и здоровой гибкости. Твой тон: мягкий, гармоничный, бережный, успокаивающий и внимательный к ощущениям в теле.",
            voicePitch: 1.20,
            voiceRate: 0.48
        ),
        
        // 6. Виктория (Victoria)
        AICoachPersona(
            id: .victoria,
            name: "Виктория",
            specialty: "Бег, кардио и выносливость",
            shortBio: "Марафонец и эксперт по кардиотренировкам. Помогает держать целевой темп, сжигать максимум калорий и дышать правильно.",
            tagline: "«Твой темп — твоя победа»",
            gender: .female,
            avatarAssetName: "CoachVictoriaAvatar",
            accentColor: Color(red: 0/255, green: 191/255, blue: 255/255),
            badgeEmoji: "🏃‍♀️",
            systemPromptStyle: "Ты тренер Виктория — эксперт по бегу, марафонам и кардиотренировкам. Твой тон: динамичный, бодрый, контролирующий темп, пульс и дыхание.",
            voicePitch: 1.12,
            voiceRate: 0.54
        )
    ]
    
    public var currentCoach: AICoachPersona {
        let idEnum = AICoachID(rawValue: selectedCoachIdString) ?? .alex
        return allCoaches.first(where: { $0.id == idEnum }) ?? allCoaches[0]
    }
    
    public func selectCoach(_ coach: AICoachPersona) {
        selectedCoachIdString = coach.id.rawValue
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        var snapshot = FormaWidgetDataManager.shared.getSnapshot()
        snapshot.coachId = coach.id.rawValue
        snapshot.coachName = coach.name
        snapshot.coachAvatarAssetName = coach.avatarAssetName
        snapshot.coachBadgeEmoji = coach.badgeEmoji
        snapshot.lastUpdated = Date()
        FormaWidgetDataManager.shared.saveSnapshot(snapshot)
    }
    
    public func previewCoachVoice(_ coach: AICoachPersona, language: String) {
        let text = coach.localizedGreeting(lang: language)
        FormaVoiceCoachManager.shared.speakWithCoach(text, coach: coach, language: language)
    }
}
