import Foundation

@main
struct SongCollectionChecks {
    static func main() {
        let emptyPage = CollectionPage(itemCount: 0, requestedIndex: 3)
        precondition(emptyPage.index == 0 && emptyPage.count == 1 && emptyPage.range.isEmpty)
        let fullPage = CollectionPage(itemCount: 7, requestedIndex: 0)
        precondition(fullPage.count == 1 && Array(fullPage.range) == Array(0..<7))
        let lastPage = CollectionPage(itemCount: 8, requestedIndex: 1)
        precondition(lastPage.count == 2 && Array(lastPage.range) == [7], "The eighth item starts a new page")
        let removedLastItem = CollectionPage(itemCount: 7, requestedIndex: 1)
        precondition(removedLastItem.index == 0 && Array(removedLastItem.range) == Array(0..<7),
                     "Removing the last page returns to a valid page")
        let severalPages = (0..<3).flatMap { CollectionPage(itemCount: 15, requestedIndex: $0).range }
        precondition(severalPages == Array(0..<15), "Pages preserve order without missing or duplicate items")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let today = calendar.date(from: DateComponents(year: 2024, month: 3, day: 1))!
        func entry(_ day: String, _ title: String?, _ artist: String? = "Artist") -> MoodEntry {
            let entry = MoodEntry(dayKey: day, choice: .good, note: "A memory")
            entry.songTitle = title
            entry.songArtist = artist
            return entry
        }
        let first = entry("2024-02-29", "  My   Song ")
        let second = entry("2024-03-01", "my song", "ARTIST")
        let cover = entry("2024-01-31", "My Song", "Another Artist")
        let blankArtist = entry("2023-12-31", "My Song", nil)
        let records = [first, second, cover, blankArtist,
                       entry("2024-03-02", "Future"), entry("2023-02-29", "Invalid"),
                       entry("2024-02-30", "Invalid"), entry("2024-01-01", " \n ")]
        var songs = EntryCollection.songs(from: records, today: today, calendar: calendar)
        precondition(songs.count == 3, "Only valid, non-future songs; artists stay separate")
        precondition(songs[0].memories.map(\.id) == ["2024-03-01", "2024-02-29"], "Merge and order leap-day memories")
        precondition(songs[1].memories[0].id == "2024-01-31", "Month/year boundaries sort by day")
        second.songTitle = nil
        songs = EntryCollection.songs(from: records, today: today, calendar: calendar)
        precondition(songs[0].memories.count == 1, "Removing a song updates its collection")
        let replacement = entry("2024-02-29", "New song")
        replacement.updatedAt = first.updatedAt.addingTimeInterval(1)
        songs = EntryCollection.songs(from: records + [replacement], today: today, calendar: calendar)
        precondition(songs[0].title == "New song", "Newest same-day revision wins")
        precondition(songs.flatMap(\.memories).count == 3, "One memory per day")
        first.watchTitle = "  A Film "
        first.watchKind = "movie"
        first.watchNote = "Keep this viewing note"
        second.watchTitle = "a film"
        second.watchKind = "MOVIE"
        cover.watchTitle = "A Film"
        cover.watchKind = "series"
        first.photoData = Data([1, 2, 3])
        second.photoData = Data([4, 5, 6])
        blankArtist.photoData = Data()
        let future = entry("2024-03-02", "Future")
        future.photoData = Data([7])
        future.watchTitle = "Future film"
        let invalid = entry("2023-02-29", nil)
        invalid.photoData = Data([8])
        invalid.watchTitle = "Invalid date film"
        let all = records + [future, invalid]
        var watches = EntryCollection.watches(from: all, today: today, calendar: calendar)
        precondition(watches.count == 2, "Merge matching titles and kinds; keep different kinds separate")
        precondition(watches[0].memories.map(\.id) == ["2024-03-01", "2024-02-29"])
        precondition(watches[0].memories[1].entry.watchNote == "Keep this viewing note")
        var photos = EntryCollection.photos(from: all, today: today, calendar: calendar)
        precondition(photos.map(\.id) == ["2024-03-01", "2024-02-29"], "Valid photos stay separate by day")
        second.photoData = nil
        second.watchTitle = nil
        watches = EntryCollection.watches(from: all, today: today, calendar: calendar)
        photos = EntryCollection.photos(from: all, today: today, calendar: calendar)
        precondition(watches[0].memories.count == 1 && photos.count == 1, "Removed media updates collections")
        precondition(EntryCollection.photos(from: all + [replacement], today: today, calendar: calendar).isEmpty,
                     "Newer same-day records remove stale photos")
        print("Music, film/TV, and photo collection checks passed")
    }
}
