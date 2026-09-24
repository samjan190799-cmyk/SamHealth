import Foundation

/// Высокопроизводительный кэш DateFormatter для исключения дорогостоящих аллокаций ICU в циклах и UI
public final class AppDateHelper: @unchecked Sendable {
    public static let shared = AppDateHelper()
    
    /// Форматтер дня для ключей словарей (yyyy-MM-dd)
    public static let isoDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.autoupdatingCurrent
        formatter.calendar = Calendar.autoupdatingCurrent
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

    /// Форматтер дня и месяца (например: "12 мая", "5 окт.")
    public static let ruDayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    /// Форматтер номера дня месяца (например: "12", "5")
    public static let ruDayNumberFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    /// Краткий день недели (например: "Пн", "Вт")
    public static let ruDayOfWeekShortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EE"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    /// Краткая дата (dd.MM.yyyy)
    public static let ruShortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    /// Полная дата (d MMMM yyyy)
    public static let ruFullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    /// Дата и время (d MMMM, HH:mm)
    public static let ruDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM, HH:mm"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    /// Месяц и год (LLLL yyyy)
    public static let ruMonthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    /// Кэшированный NumberFormatter для разделения тысяч пробелом
    public static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.locale = Locale(identifier: "ru_RU")
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

    /// Форматирование целого числа с разделителями тысяч (например: 12 500)
    @inline(__always)
    public static func formatNumber(_ value: Int) -> String {
        decimalFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// Форматирование миллилитров с пробелом
    @inline(__always)
    public static func formatMl(_ ml: Int) -> String {
        "\(formatNumber(ml)) мл"
    }

    /// Быстрый краткий день недели (Пн, Вт, Ср...)
    @inline(__always)
    public static func dayOfWeekShort(from date: Date) -> String {
        ruDayOfWeekShortFormatter.string(from: date).capitalized
    }

    /// Быстрый номер дня (1, 2, 15...)
    @inline(__always)
    public static func dayNumber(from date: Date) -> String {
        ruDayNumberFormatter.string(from: date)
    }

    /// Быстрая дата вида "15 мая"
    @inline(__always)
    public static func dayMonth(from date: Date) -> String {
        ruDayMonthFormatter.string(from: date)
    }

    /// Быстрая дата и время вида "15 мая, 14:30"
    @inline(__always)
    public static func dateTime(from date: Date) -> String {
        ruDateTimeFormatter.string(from: date)
    }
}
