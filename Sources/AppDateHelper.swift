import Foundation

/// Высокопроизводительный кэш DateFormatter для исключения дорогостоящих аллокаций ICU в циклах и UI
public final class AppDateHelper: @unchecked Sendable {
    public static let shared = AppDateHelper()
    
    /// Форматтер дня для ключей словарей (yyyy-MM-dd)
    public static let isoDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    /// Форматтер времени (HH:mm)
    public static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    /// Быстрый ключ текущего дня (yyyy-MM-dd) без аллокации DateFormatter
    @inline(__always)
    public static var todayKey: String {
        isoDayFormatter.string(from: Date())
    }
    
    /// Ключ для произвольной даты
    @inline(__always)
    public static func dayKey(for date: Date) -> String {
        isoDayFormatter.string(from: date)
    }
}
