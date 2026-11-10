import Foundation

// 調べるとストーリーが進むもの（金色の「！」を出すもの）。
// 各章の「いまやること」（objective / bookObjective）が指しているものと合わせてある

extension NightLibraryView {
    /// 図書室で、いまストーリーが進むもの
    static func isStoryTarget(_ interactable: NightLibraryInteractable, story: StoryStore) -> Bool {
        switch chapter(story) {
        case .prologue: PrologueEvents.isStoryTarget(interactable, story: story)
        case .chapter1: Chapter1Events.isStoryTarget(interactable, story: story)
        case .chapter2: interactable == .tama && !story.has(.chapter2Cleared)
        case .chapter3: interactable == .sachi && !story.has(.chapter3Cleared)
        case .chapter4: interactable == .brothers && !story.has(.chapter4Cleared)
        case .chapter5: Chapter5Events.isStoryTarget(interactable, story: story)
        case .finale: FinaleEvents.isStoryTarget(interactable, story: story)
        }
    }
}

extension PrologueEvents {
    static func isStoryTarget(_ interactable: NightLibraryInteractable, story: StoryStore) -> Bool {
        guard story.has(.prologueMetFumi), !story.has(.prologueCleared) else { return false }
        switch interactable {
        case .child:
            return !story.has(.prologueChildPassed) && (!story.has(.prologueChildAsked) || story.has(.pictureBook))
        case .pictureBookShelf:
            return story.has(.prologueChildAsked) && !story.has(.pictureBook) && !story.has(.prologueChildPassed)
        case .bookmark:
            return story.has(.prologueChildPassed) && !story.has(.prologueFoundBookmark)
        case .bookshelf(NightLibraryInteractable.cornerShelf):
            return story.has(.prologueFoundBookmark) && !story.has(.prologueBookmarkShelved)
        default:
            return false
        }
    }
}

extension Chapter1Events {
    /// 図書室
    static func isStoryTarget(_ interactable: NightLibraryInteractable, story: StoryStore) -> Bool {
        guard story.has(.chapter1Started), !story.has(.chapter1Cleared) else { return false }
        let isLookingForBookmark = story.has(.chapter1AskedBookmark) && !story.has(.chapter1FoundBookmark)
        switch interactable {
        case .taku: return !isLookingForBookmark
        case .takuBookmark: return isLookingForBookmark
        default: return false
        }
    }

    /// 本の中（『走れメロス』）
    static func isStoryTarget(_ interactable: MelosInteractable, story: StoryStore, clock: SunsetClock) -> Bool {
        if clock.isMelosDown {
            return interactable == .rock(MelosInteractable.springRock)
        }
        switch interactable {
        case .river: return !story.has(.chapter1RiverCrossed)
        case .bandits: return story.has(.chapter1RiverCrossed) && !story.has(.chapter1BanditsPassed)
        case .collapse: return story.has(.chapter1BanditsPassed) && !story.has(.chapter1MelosRevived)
        case .philostratus: return story.has(.chapter1MelosRevived) && !story.has(.chapter1PhilostratusPassed)
        case .gate: return story.has(.chapter1PhilostratusPassed) && !story.has(.chapter1ReachedEnd)
        case .rock, .melosLying: return false
        }
    }
}

extension Chapter2Events {
    /// 本の中（『吾輩は猫である』）。まだ拾っていないキヨさんの書き込み
    static func isStoryTarget(_ interactable: NekoInteractable, story: StoryStore, progress: NoteProgress) -> Bool {
        switch interactable {
        case .hedgeNote: !story.has(.chapter2NoteHedge)
        case .master: !story.has(.chapter2NoteStudy)
        case .zouni: !story.has(.chapter2NoteKitchen)
        case .mikeko: !story.has(.chapter2NoteMikeko)
        case .brazier: progress.count >= NoteProgress.total - 1 && !story.has(.chapter2NoteBrazier)
        case .kamado, .table: false
        }
    }
}

extension Chapter3Events {
    /// 本の中（『銀河鉄道の夜』）
    static func isStoryTarget(_ interactable: GingaInteractable, story: StoryStore, scene: GingaScene) -> Bool {
        let ticketShown = story.has(.chapter3TicketShown)
        let candyEaten = story.has(.chapter3CandyEaten)
        let appleTaken = story.has(.chapter3AppleTaken)
        switch interactable {
        case .seat(let index):
            // 置いた手紙は、忘れずに拾う
            return scene.letterSeat == index
        case .door(let index):
            let episodeDone = [ticketShown, candyEaten, appleTaken]
            return episodeDone.indices.contains(index) && episodeDone[index] && !scene.openedDoors.contains(index)
        case .conductor: return !ticketShown
        case .birdCatcher: return ticketShown && !candyEaten
        case .lighthouseKeeper: return candyEaten && !appleTaken
        case .author: return appleTaken && !story.has(.chapter3LetterDelivered)
        case .doorway, .giovanni, .campanella: return false
        }
    }

    /// 開けたあとの扉や、もう何も起きない車両のつなぎ目は、調べられないようにする
    static func isAvailable(_ interactable: GingaInteractable, story: StoryStore, scene: GingaScene) -> Bool {
        switch interactable {
        case .door(let index):
            return !scene.openedDoors.contains(index)
        case .doorway(let index):
            // 手紙を置き忘れて先へ進もうとしたときと、終点に着いたときだけ
            if let car = scene.letterCar, car <= index { return true }
            return index == 2 && scene.isCarryingLetter && !story.has(.chapter3LetterDelivered)
        default:
            return true
        }
    }
}

extension Chapter4Events {
    /// 本の中（『注文の多い料理店』）。まだ開けていない扉と、まだすませていない注文
    static func isStoryTarget(_ interactable: YamanekoInteractable, scene: YamanekoScene) -> Bool {
        switch interactable {
        case .door(let index): !scene.openedDoors.contains(index)
        case .station(let station): !scene.doneStations.contains(station)
        case .doorway, .signboard: false
        }
    }

    /// 開けたあとの扉や、もう裏を読んだ扉のくぐり口は、調べられないようにする
    static func isAvailable(_ interactable: YamanekoInteractable, story: StoryStore, scene: YamanekoScene) -> Bool {
        switch interactable {
        case .door(6): !story.has(.chapter4Escaped)
        case .door(let index): !scene.openedDoors.contains(index)
        case .doorway(let index): !scene.passedDoorways.contains(index) && hasBackText(index)
        default: true
        }
    }
}

extension Chapter5Events {
    static func isStoryTarget(_ interactable: NightLibraryInteractable, story: StoryStore) -> Bool {
        guard story.has(.chapter5Started), !story.has(.chapter5Cleared) else { return false }
        switch interactable {
        case .bookshelf(NightLibraryInteractable.cornerShelf):
            return !story.has(.chapter5FoundGap)
        case .cardBox:
            return story.has(.chapter5FoundGap) && !story.has(.chapter5ReadCard)
        case .fumi:
            return (story.has(.chapter5ReadCard) && !story.has(.chapter5AskedFumi)) || story.has(.chapter5SawShadow)
        case .shadow:
            return story.has(.chapter5AskedFumi) && !story.has(.chapter5SawShadow)
        default:
            return false
        }
    }
}

extension FinaleEvents {
    /// 図書室
    static func isStoryTarget(_ interactable: NightLibraryInteractable, story: StoryStore) -> Bool {
        switch interactable {
        case .fumi:
            return story.has(.finaleStarted) && !story.has(.finaleFoundHaru)
        case .haru:
            return story.has(.finaleFoundHaru) && !story.has(.finaleReadToEnd)
        case .bookshelf:
            // 朝の図書室で、本棚の前へ行く
            return story.has(.finaleCleared) && !story.has(.epilogueCleared)
        default:
            return false
        }
    }

    /// 本の中（『手袋を買いに』）
    static func isStoryTarget(_ interactable: TebukuroInteractable, story: StoryStore) -> Bool {
        switch interactable {
        case .foxes: !story.has(.finaleGotCoins)
        case .hatShop: story.has(.finaleGotCoins) && !story.has(.finaleGotMittens)
        case .haru: story.has(.finaleGotMittens) && !story.has(.finaleFoundHaru)
        case .footprints, .glimpse, .sign, .lullabyWindow: false
        }
    }
}
