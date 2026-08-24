import Foundation
import AVFoundation
import SwiftUI
import Combine

@MainActor
public class FormaVoiceCoachManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    public static let shared = FormaVoiceCoachManager()
    
    private let synthesizer = AVSpeechSynthesizer()
    
    // Настройки озвучки
    @AppStorage("voice_coach_enabled") public var isVoiceCoachEnabled: Bool = true
    @AppStorage("voice_coach_splits_enabled") public var announceKilometers: Bool = true
    @AppStorage("voice_coach_intervals_enabled") public var announceTimeIntervals: Bool = true
    @AppStorage("voice_coach_hr_alerts_enabled") public var announceHeartRateAlerts: Bool = true
    
    // Внутреннее состояние трекера для предотвращения спама
    private var lastAnnouncedKm: Int = 0
    private var lastAnnouncedFiveMin: Int = 0
    private var lastHRWarningDate: Date = .distantPast
    private var lastRestCountdownSecond: Int = -1
    
    public override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .voicePrompt,
                options: [.duckOthers, .mixWithOthers]
            )
        } catch {
            print("[VoiceCoach] AudioSession setup error: \(error)")
        }
    }
    
    /// Сброс состояния для новой тренировки
    public func resetForNewWorkout() {
        lastAnnouncedKm = 0
        lastAnnouncedFiveMin = 0
        lastHRWarningDate = .distantPast
        lastRestCountdownSecond = -1
        synthesizer.stopSpeaking(at: .immediate)
    }
    
    // MARK: - Озвучка текста
    
    public func speak(_ text: String, coach: AICoachPersona? = nil, language: String = "ru") {
        guard isVoiceCoachEnabled, !text.isEmpty else { return }
        
        let targetCoach = coach ?? AICoachManager.shared.currentCoach
        let utterance = AVSpeechUtterance(string: text)
        
        // Выбор локали голоса
        let voiceCode: String
        switch language {
        case "en": voiceCode = "en-US"
        case "hy": voiceCode = "hy-AM"
        default: voiceCode = "ru-RU"
        }
        
        if let voice = AVSpeechSynthesisVoice(language: voiceCode) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "ru-RU")
        }
        
        utterance.rate = targetCoach.voiceRate // Индивидуальный темп речи тренера
        utterance.pitchMultiplier = targetCoach.voicePitch // Индивидуальный тембр и высота голоса
        utterance.volume = 1.0
        
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("[VoiceCoach] Failed to activate audio session: \(error)")
        }
        
        synthesizer.speak(utterance)
    }
    
    public func speakWithCoach(_ text: String, coach: AICoachPersona, language: String = "ru") {
        speak(text, coach: coach, language: language)
    }
    
    // MARK: - Триггеры событий тренировки
    
    /// Приветствие и старт
    public func onWorkoutStart(workoutType: String, language: String) {
        resetForNewWorkout()
        
        let coach = AICoachManager.shared.currentCoach
        let message: String
        switch language {
        case "en":
            message = "Hi! I'm Coach \(coach.name). Starting workout: \(workoutType). Keep a steady pace and breathe smoothly!"
        case "hy":
            message = "Ողջույն! Ես քո մարզիչ \(coach.name)-ն եմ: Սկսում ենք մարզումը՝ \(workoutType):"
        default:
            message = "Привет! Я твой тренер \(coach.name). Начинаем тренировку: \(workoutType). \(coach.tagline)!"
        }
        speak(message, coach: coach, language: language)
    }
    
    /// Мониторинг прогресса (каждые N секунд)
    public func onWorkoutTick(
        elapsedSeconds: Int,
        distanceMeters: Double,
        calories: Int,
        heartRate: Int,
        language: String
    ) {
        guard isVoiceCoachEnabled else { return }
        
        // 1. Озвучка пройденных километров
        if announceKilometers && distanceMeters >= 1000.0 {
            let currentKm = Int(distanceMeters / 1000.0)
            if currentKm > lastAnnouncedKm {
                lastAnnouncedKm = currentKm
                let kmSeconds = elapsedSeconds / max(1, currentKm)
                let mins = kmSeconds / 60
                let secs = kmSeconds % 60
                
                let message: String
                switch language {
                case "en":
                    message = "Kilometer \(currentKm) completed. Pace: \(mins) minutes \(secs) seconds. Heart rate: \(heartRate) BPM. Great work!"
                case "hy":
                    message = "Անցել ես \(currentKm)-րդ կիլոմետրը: Տեմպը՝ \(mins) րոպե \(secs) վայրկյան: Պուլսը՝ \(heartRate):"
                default:
                    let hrText = heartRate > 0 ? ", пульс \(heartRate) ударов в минуту." : "."
                    message = "Пройден \(currentKm)-й километр за \(mins) минут \(secs) секунд\(hrText) Отличный темп!"
                }
                speak(message, language: language)
                return
            }
        }
        
        // 2. Озвучка 5-минутных интервалов времени
        if announceTimeIntervals && elapsedSeconds >= 300 {
            let fiveMinChunk = elapsedSeconds / 300
            if fiveMinChunk > lastAnnouncedFiveMin {
                lastAnnouncedFiveMin = fiveMinChunk
                let totalMinutes = elapsedSeconds / 60
                
                let message: String
                switch language {
                case "en":
                    message = "\(totalMinutes) minutes of workout completed. You've burned \(calories) calories. Keep going!"
                case "hy":
                    message = "Անցել է \(totalMinutes) րոպե: Այրվել է \(calories) կալորիա:"
                default:
                    message = "Прошло \(totalMinutes) минут тренировки. Сожжено \(calories) килокалорий. Ты в отличной форме!"
                }
                speak(message, language: language)
                return
            }
        }
        
        // 3. Оповещение о высоком пульсе в пиковой зоне
        if announceHeartRateAlerts && heartRate >= 165 {
            let now = Date()
            if now.timeIntervalSince(lastHRWarningDate) > 120 { // Не чаще раза в 2 минуты
                lastHRWarningDate = now
                let message: String
                switch language {
                case "en":
                    message = "Warning: Heart rate reached \(heartRate) BPM. Take a deep breath and slightly slow down."
                case "hy":
                    message = "Ուշադրություն: Պուլսը հասել է \(heartRate) զարկի: Խորը շնչիր և մի փոքր իջեցրու տեմպը:"
                default:
                    message = "Внимание: пульс достиг \(heartRate) ударов в минуту. Сделай глубокий вдох и немного сбавь темп."
                }
                speak(message, language: language)
            }
        }
    }
    
    /// Озвучка завершения сета и начала отдыха в личной тренировке
    public func onSetCompleted(
        exerciseName: String,
        completedSet: Int,
        totalSets: Int,
        restSeconds: Int,
        language: String
    ) {
        let message: String
        switch language {
        case "en":
            message = "Set \(completedSet) of \(totalSets) in \(exerciseName) completed! Rest for \(restSeconds) seconds. Drink some water."
        case "hy":
            message = "\(exerciseName)՝ մոտեցում \(completedSet)-ը \(totalSets)-ից ավարտվեց: Հանգիստ \(restSeconds) վայրկյան:"
        default:
            message = "Подход \(completedSet) из \(totalSets) в упражнении \(exerciseName) завершен! Время отдыха: \(restSeconds) секунд. Сделай глоток воды."
        }
        speak(message, language: language)
    }
    
    /// Обратный отсчет таймера отдыха (на последних 3 секундах)
    public func onRestCountdownTick(secondsRemaining: Int, nextExerciseName: String, language: String) {
        guard isVoiceCoachEnabled else { return }
        
        if secondsRemaining <= 3 && secondsRemaining > 0 && lastRestCountdownSecond != secondsRemaining {
            lastRestCountdownSecond = secondsRemaining
            speak("\(secondsRemaining)", language: language)
        } else if secondsRemaining == 0 && lastRestCountdownSecond != 0 {
            lastRestCountdownSecond = 0
            let message: String
            switch language {
            case "en":
                message = "Rest is over! Start next set: \(nextExerciseName)!"
            case "hy":
                message = "Հանգիստն ավարտվեց: Սկսում ենք՝ \(nextExerciseName)!"
            default:
                message = "Время отдыха вышло! Начинаем: \(nextExerciseName)!"
            }
            speak(message, language: language)
        }
    }
    
    /// Завершение тренировки
    public func onWorkoutFinish(
        durationSeconds: Int,
        calories: Int,
        distanceMeters: Double,
        language: String
    ) {
        let minutes = durationSeconds / 60
        let km = distanceMeters / 1000.0
        
        let message: String
        switch language {
        case "en":
            let distStr = km > 0.1 ? String(format: ", distance: %.2f km", km) : ""
            message = "Workout completed! Duration: \(minutes) minutes, burned: \(calories) calories\(distStr). Excellent job!"
        case "hy":
            let distStr = km > 0.1 ? String(format: ", հեռավորություն՝ %.2f կմ", km) : ""
            message = "Մարզումն ավարտվեց: Ժամանակ՝ \(minutes) րոպե, այրված՝ \(calories) կալորիա\(distStr): Հիանալի աշխատանք:"
        default:
            let distStr = km > 0.1 ? String(format: ", дистанция: %.2f км", km) : ""
            message = "Отличная работа! Тренировка завершена. Время: \(minutes) минут, сожжено: \(calories) килокалорий\(distStr). Ты сегодня молодец!"
        }
        speak(message, language: language)
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Деактивируем аудиосессию для возврата оригинальной громкости музыки
        Task { @MainActor in
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
