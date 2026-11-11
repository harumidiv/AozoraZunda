import Foundation

/// 朝の町での、ストーリーのおつかいの会話。夜の図書室で頼まれたものを、町の人から受けとる
struct StoryDayEvents {
    let runner: StoryRunner
    let story: StoryStore

    /// いまのおつかいの相手なら、その会話をして true を返す。ちがえば何もしない
    func talk(to person: Townsperson) async -> Bool {
        guard let task = StoryDayTask.current(story), task.person == person else { return false }
        switch task {
        case .tamaBell: await findBell()
        case .stamp: await getStamp()
        case .anpan: await getAnpan()
        case .haruRumor: await hearOfHaru()
        case .melosBook, .tebukuroBook: return false
        }
        return true
    }

    /// 昼の図書館で本を借りるおつかいのあいだ、町の人がしてくれる話（そのあと、ふだんの会話につづく）
    func hint(from person: Townsperson) async {
        let speaker = StorySpeaker.townsperson(person)
        switch (StoryDayTask.current(story), person) {
        case (.melosBook, .grandpa):
            await runner.say(speaker, "『走れメロス』か。わしも学生のころ、通学の汽車でよう読んだもんじゃ")
            await runner.say(speaker, "むかしはこの町にも駅があってな。学ランの子らが、本を読みながら汽車を待っとった")
            await runner.say(.zunda, "（学ラン……タクみたいなのだ）")
        case (.melosBook, .student):
            await runner.say(speaker, "太宰治なら、図書館の「た」の棚だよ。司書さんに聞いても、すぐ出してくれるよ")
        case (.tebukuroBook, .student):
            await runner.say(speaker, "『手袋を買いに』？ 新美南吉の本なら、図書館の「な」の棚にあるよ")
            await runner.say(speaker, "冬になると、子どもたちがよく借りてくの。……ずっと、読まれてる本なんだね")
        case (.tebukuroBook, .grandpa):
            await runner.say(speaker, "……雪の日の窓ぎわの子にも、あの本、読ませてやりたかったのう")
        default:
            break
        }
    }

    // MARK: - 第2章: タマの鈴

    private func findBell() async {
        let gen = StorySpeaker.townsperson(.grandpa)
        await runner.say(.zunda, "ゲンさん。このベンチのあたりで、鈴を見なかったのだ？ 猫の首輪の、ちいさな鈴なのだ")
        await runner.say(gen, "鈴？ ……おお、それならベンチの下じゃ。ずうっと昔から、板のすきまに引っかかっとってな")
        await runner.say(gen, "わしが子どものころ、このベンチで、本を読むばあさんがおってな。ひざの上に、いっつも猫が寝とった")
        await runner.say(.zunda, "……キヨさん、なのだ？")
        await runner.say(gen, "おお、そうじゃ、キヨさんじゃ。猫はタマいうてな。キヨさんが笑うと、タマが鈴を鳴らして返事しよった")
        await runner.say(gen, "持っていきんさい。……なんでか知らんが、あんたが持っとるほうが、ええ気がするわい")
        story.give(.tamaBell)
        story.set(.chapter2GotBell)
        await runner.showItemGet(.tamaBell)
        await runner.say(.zunda, "ありがとうなのだ、ゲンさん。……夜になったら、届けるのだ")
    }

    // MARK: - 第3章: サチの手紙の切手

    private func getStamp() async {
        let yui = StorySpeaker.townsperson(.student)
        await runner.say(.zunda, "ユイさん。切手って、持ってるのだ？")
        await runner.say(yui, "切手？ あるよ。レポートで宮沢賢治のことを調べてたら、記念切手まで集めちゃって")
        await runner.say(yui, "賢治って、生きてるうちは、ほとんど知られてなかったんだって。「あなたの本が好きです」って手紙、もっともらえてたらよかったのにね")
        await runner.say(.zunda, "……その人に、手紙を出したい子がいるのだ。ずっと、出せなかったのだ")
        await runner.say(yui, "……そっか")
        await runner.say(yui, "じゃあ、これ。星空と汽車の切手。その手紙に、きっと似合う")
        story.give(.stamp)
        story.set(.chapter3GotStamp)
        await runner.showItemGet(.stamp)
        await runner.say(yui, "ちゃんと届くといいね")
        await runner.say(.zunda, "届くのだ。ずんだもんが、終点まで持っていくのだ")
    }

    // MARK: - 第4章: 兄弟へのおそなえもの

    private func getAnpan() async {
        let mitsu = StorySpeaker.townsperson(.baker)
        await runner.say(.zunda, "ミツさん、あんパンくださいなのだ。ふたつ！")
        await runner.say(mitsu, "はいはい。……あら、ずんだもんちゃんが甘いパンなんて、めずらしいわね")
        await runner.say(.zunda, "おそなえものなのだ。腹ぺこの、兄弟の")
        await runner.say(mitsu, "兄弟……。そういえば、おばあちゃんから聞いた話があるの")
        await runner.say(mitsu, "むかし、図書館の帰りに、毎日あんパンを一つだけ買って、店先で半分こしてく兄弟がいたんだって")
        await runner.say(mitsu, "それでね、食べながら本を声に出して読むのよ。お兄ちゃんが地の文で、弟がセリフ。お客さんが笑って、お店がにぎやかになったって")
        await runner.say(.zunda, "……その兄弟、たぶん、知ってるのだ")
        await runner.say(mitsu, "あら、そうなの？ ……じゃあ、お代はいいわ。焼きたてを、ふたつ")
        story.give(.anpan)
        story.set(.chapter4GotFood)
        await runner.showItemGet(.anpan)
        await runner.say(mitsu, "半分こじゃなくて、ひとり一個ずつ。おなかいっぱいにしてあげて")
    }

    // MARK: - 第5章: むかしの「はる」

    private func hearOfHaru() async {
        let gen = StorySpeaker.townsperson(.grandpa)
        await runner.say(.zunda, "ゲンさん。「はる」って子、知ってるのだ？ ずっとむかし、図書館で本を借りてた子なのだ")
        await runner.say(gen, "はる……。……ああ。ああ、おったのう")
        await runner.say(gen, "図書館の前の家に、体の弱い女の子がおってな。雪の日も外で遊べんで、いっつも窓ぎわで本を読んどった")
        await runner.say(gen, "わしら悪ガキが雪合戦しとると、窓から、うらやましそうに見とってのう。……一回くらい、誘ってやればよかった")
        await runner.say(gen, "図書館の司書さんがな、よう、その子の家に本を届けに行っとった。やさしい人じゃった")
        await runner.say(gen, "……ある冬から、窓に明かりがつかんようになってな。それきりじゃ")
        await runner.say(.zunda, "…………")
        await runner.say(.zunda, "（図書館の司書さん……。おフミさんなのだ）")
        story.set(.chapter5HeardOfHaru)
        await runner.say(.zunda, "ありがとうなのだ、ゲンさん。……今夜、図書室で、ちゃんと聞いてみるのだ")
        await runner.say(gen, "……なんじゃ、しんみりしてしもうたのう。ほれ、日なたは気持ちええぞ")
    }
}
