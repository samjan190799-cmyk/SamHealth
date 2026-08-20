import Foundation
import AVFoundation
import MusicKit
import Combine
import UIKit

public enum MusicSource: String, CaseIterable, Identifiable {
    case radio = "Workout Radio"
    case appleMusic = "Apple Music"
    
    public var id: String { self.rawValue }
}

public class WorkoutMusicManager: ObservableObject {
    public static let shared = WorkoutMusicManager()
    
    @Published public var isPlaying = false
    @Published public var currentTrackTitle = "Не воспроизводится"
    @Published public var currentArtist = ""
    @Published public var currentArtwork: UIImage? = nil
    @Published public var currentSource: MusicSource = .radio
    @Published public var isAppleMusicAuthorized = false
    @Published public var availablePlaylists: [Playlist] = []
    
    private var avPlayer: AVPlayer?
    private var cancellables = Set<AnyCancellable>()
    private var appleMusicPlayer = ApplicationMusicPlayer.shared
    
    // Ссылки на стабильные спортивные онлайн-радиостанции
    private let radioStreams = [
        "https://stream.dancewave.online/dance.mp3",                          // Dance Wave
        "https://icecast.ndr.de/ndr/ndr2/hamburg/mp3/128/stream.mp3",         // NDR 2
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"       // Тестовый трек
    ]
    private var currentRadioIndex = 0
    
    private init() {
        setupAudioSession()
        checkAppleMusicAuthorization()
        observeAppleMusicPlayer()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Не удалось настроить аудиосессию: \(error.localizedDescription)")
        }
    }
    
    // --- ПРОВЕРКА И ЗАПРОС АВТОРИЗАЦИИ APPLE MUSIC ---
    public func checkAppleMusicAuthorization() {
        let status = MusicAuthorization.currentStatus
        DispatchQueue.main.async {
            self.isAppleMusicAuthorized = (status == .authorized)
        }
    }
    
    public func requestAppleMusicAccess() async {
        let status = await MusicAuthorization.request()
        await MainActor.run {
            self.isAppleMusicAuthorized = (status == .authorized)
        }
    }
    
    // --- НАБЛЮДЕНИЕ ЗА APPLE MUSIC PLAYER ---
    private func observeAppleMusicPlayer() {
        // Следим за изменениями состояния воспроизведения
        appleMusicPlayer.state.objectWillChange
            .sink { [weak self] _ in
                self?.updateAppleMusicMetadata()
            }
            .store(in: &cancellables)
    }
    
    private func updateAppleMusicMetadata() {
        DispatchQueue.main.async {
            let state = self.appleMusicPlayer.state
            self.isPlaying = (state.playbackStatus == .playing)
            
            if self.currentSource == .appleMusic {
                if let currentEntry = self.appleMusicPlayer.queue.currentEntry {
                    self.currentTrackTitle = currentEntry.title
                    self.currentArtist = currentEntry.subtitle ?? ""
                    
                    // Загрузка обложки трека в фоновом режиме
                    if let artwork = currentEntry.artwork,
                       let url = artwork.url(width: 300, height: 300) {
                        Task {
                            if let (data, _) = try? await URLSession.shared.data(from: url),
                               let image = UIImage(data: data) {
                                await MainActor.run {
                                    self.currentArtwork = image
                                }
                            }
                        }
                    } else {
                        self.currentArtwork = nil
                    }
                } else {
                    self.currentTrackTitle = "Apple Music"
                    self.currentArtist = "Выберите плейлист или трек"
                    self.currentArtwork = nil
                }
            }
        }
    }
    
    // --- УПРАВЛЕНИЕ ВОСПРОИЗВЕДЕНИЕМ ---
    public func play() {
        if currentSource == .radio {
            playRadio()
        } else {
            playAppleMusic()
        }
    }
    
    public func pause() {
        if currentSource == .radio {
            avPlayer?.pause()
            isPlaying = false
        } else {
            appleMusicPlayer.pause()
            isPlaying = false
        }
    }
    
    public func next() {
        if currentSource == .radio {
            // Переключаем радиостанцию
            currentRadioIndex = (currentRadioIndex + 1) % radioStreams.count
            playRadio()
        } else {
            Task {
                try? await appleMusicPlayer.skipToNextEntry()
                updateAppleMusicMetadata()
            }
        }
    }
    
    public func previous() {
        if currentSource == .radio {
            currentRadioIndex = (currentRadioIndex - 1 + radioStreams.count) % radioStreams.count
            playRadio()
        } else {
            Task {
                try? await appleMusicPlayer.skipToPreviousEntry()
                updateAppleMusicMetadata()
            }
        }
    }
    
    public func toggleSource(to source: MusicSource) {
        pause()
        currentSource = source
        
        if source == .radio {
            currentTrackTitle = "Workout Radio"
            currentArtist = "Энергичный фитнес-микс"
            currentArtwork = nil
        } else {
            if isAppleMusicAuthorized {
                updateAppleMusicMetadata()
                Task {
                    await fetchPlaylists()
                }
            } else {
                currentTrackTitle = "Apple Music"
                currentArtist = "Требуется авторизация"
                currentArtwork = nil
            }
        }
    }
    
    // --- РАДИО МЕТОДЫ ---
    private func playRadio() {
        guard let url = URL(string: radioStreams[currentRadioIndex]) else { return }
        
        // Сброс старого плеера
        avPlayer?.pause()
        
        let playerItem = AVPlayerItem(url: url)
        avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer?.play()
        
        isPlaying = true
        currentTrackTitle = currentRadioIndex == 0 ? "Dance Fitness Mix" : (currentRadioIndex == 1 ? "Energy Power Beat" : "Synth Workout Track")
        currentArtist = "Workout Radio (Канал \(currentRadioIndex + 1))"
        currentArtwork = nil
    }
    
    // --- APPLE MUSIC МЕТОДЫ ---
    private func playAppleMusic() {
        guard isAppleMusicAuthorized else {
            Task {
                await requestAppleMusicAccess()
            }
            return
        }
        
        Task {
            do {
                // Если очередь пуста, попробуем загрузить стандартный плейлист для тренировок
                if appleMusicPlayer.queue.entries.isEmpty {
                    let request = MusicCatalogSearchRequest(term: "Workout", types: [Playlist.self])
                    let response = try await request.response()
                    if let workoutPlaylist = response.playlists.first {
                        appleMusicPlayer.queue = [workoutPlaylist]
                    }
                }
                
                try await appleMusicPlayer.play()
                await MainActor.run {
                    self.isPlaying = true
                    self.updateAppleMusicMetadata()
                }
            } catch {
                print("Ошибка воспроизведения Apple Music: \(error.localizedDescription)")
            }
        }
    }
    
    // --- ЗАГРУЗКА И ВОСПРОИЗВЕДЕНИЕ ПЛЕЙЛИСТОВ ---
    public func fetchPlaylists() async {
        guard isAppleMusicAuthorized else { return }
        do {
            let request = MusicLibraryRequest<Playlist>()
            let response = try await request.response()
            var list = Array(response.items)
            
            // Если личная медиатека пуста (например, в симуляторе),
            // загружаем спортивные плейлисты из каталога Apple Music
            if list.isEmpty {
                let catalogRequest = MusicCatalogSearchRequest(term: "Workout", types: [Playlist.self])
                let catalogResponse = try await catalogRequest.response()
                list = Array(catalogResponse.playlists)
            }
            
            let finalPlaylists = list
            await MainActor.run {
                self.availablePlaylists = finalPlaylists
            }
        } catch {
            print("Ошибка загрузки плейлистов: \(error.localizedDescription)")
            
            // В случае ошибки доступа к медиатеке пробуем загрузить из каталога
            do {
                let catalogRequest = MusicCatalogSearchRequest(term: "Workout", types: [Playlist.self])
                let catalogResponse = try await catalogRequest.response()
                let finalPlaylists = Array(catalogResponse.playlists)
                await MainActor.run {
                    self.availablePlaylists = finalPlaylists
                }
            } catch {
                print("Ошибка каталога Apple Music: \(error.localizedDescription)")
            }
        }
    }
    
    public func playPlaylist(_ playlist: Playlist) {
        currentSource = .appleMusic
        Task {
            do {
                appleMusicPlayer.queue = [playlist]
                try await appleMusicPlayer.play()
                await MainActor.run {
                    self.isPlaying = true
                    self.updateAppleMusicMetadata()
                }
            } catch {
                print("Ошибка воспроизведения плейлиста: \(error.localizedDescription)")
            }
        }
    }
}
