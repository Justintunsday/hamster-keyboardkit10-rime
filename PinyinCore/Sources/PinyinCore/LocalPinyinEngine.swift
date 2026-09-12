import Foundation

public struct LocalPinyinEngine: PinyinEngine, Sendable {
    private struct LexiconEntry: Sendable {
        let text: String
        let pinyin: String
        let frequency: Int
    }

    private static let legalSyllables: Set<String> = Set(
        """
        a ai an ang ao ba bai ban bang bao bei ben beng bi bian biao bie bin bing bo bu
        ca cai can cang cao ce cen ceng cha chai chan chang chao che chen cheng chi
        chong chou chu chua chuai chuan chuang chui chun chuo ci cong cou cu cuan cui
        cun cuo da dai dan dang dao de dei den deng di dia dian diao die ding diu dong
        dou du duan dui dun duo e ei en eng er fa fan fang fei fen feng fo fou fu ga
        gai gan gang gao ge gei gen geng gong gou gu gua guai guan guang gui gun guo
        ha hai han hang hao he hei hen heng hong hou hu hua huai huan huang hui hun huo
        ji jia jian jiang jiao jie jin jing jiong ju juan jue jun ka kai kan kang kao
        ke ken keng kong kou ku kua kuai kuan kuang kui kun kuo la lai lan lang lao le
        lei leng li lia lian liang liao lie lin ling liu long lou lu lv lve luan lun
        luo ma mai man mang mao me mei men meng mi mian miao mie min ming miu mo mou mu
        na nai nan nang nao ne nei nen neng ni nian niang niao nie nin ning niu nong nu
        nv nve nuan nuo o ou pa pai pan pang pao pei pen peng pi pian piao pie pin ping
        po pou pu qi qia qian qiang qiao qie qin qing qiong qiu qu quan que qun ran
        rang rao re ren reng ri rong rou ru rua ruan rui run ruo sa sai san sang sao se
        sen seng sha shai shan shang shao she shen sheng shi shou shu shua shuai shuan
        shuang shui shun shuo si song sou su suan sui sun suo ta tai tan tang tao te
        teng ti tian tiao tie ting tong tou tu tua tuan tui tun tuo wa wai wan wang wei
        wen weng wo wu xi xia xian xiang xiao xie xin xing xiong xiu xu xuan xue xun ya
        yan yang yao ye yi yin ying yo yong you yu yuan yue yun za zai zan zang zao ze
        zei zen zeng zha zhai zhan zhang zhao zhe zhen zheng zhi zhong zhou zhu zhua
        zhuai zhuan zhuang zhui zhun zhuo zi zong zou zu zuan zui zun zuo
        """
        .split { $0 == " " || $0 == "\n" }
        .map(String.init)
    )

    private let entries: [LexiconEntry]

    public init() {
        self.entries = [
            LexiconEntry(text: "你", pinyin: "ni", frequency: 12_000),
            LexiconEntry(text: "好", pinyin: "hao", frequency: 11_000),
            LexiconEntry(text: "你好", pinyin: "nihao", frequency: 15_000),
            LexiconEntry(text: "我", pinyin: "wo", frequency: 13_000),
            LexiconEntry(text: "爱", pinyin: "ai", frequency: 9_000),
            LexiconEntry(text: "我爱你", pinyin: "woaini", frequency: 14_000),
            LexiconEntry(text: "中", pinyin: "zhong", frequency: 8_000),
            LexiconEntry(text: "国", pinyin: "guo", frequency: 7_000),
            LexiconEntry(text: "中国", pinyin: "zhongguo", frequency: 16_000),
            LexiconEntry(text: "人", pinyin: "ren", frequency: 8_500),
            LexiconEntry(text: "中国人", pinyin: "zhongguoren", frequency: 13_500),
            LexiconEntry(text: "谢", pinyin: "xie", frequency: 8_000),
            LexiconEntry(text: "谢谢", pinyin: "xiexie", frequency: 15_000),
            LexiconEntry(text: "谢谢你", pinyin: "xiexieni", frequency: 12_500),
            LexiconEntry(text: "世", pinyin: "shi", frequency: 7_500),
            LexiconEntry(text: "界", pinyin: "jie", frequency: 7_000),
            LexiconEntry(text: "世界", pinyin: "shijie", frequency: 13_000),
            LexiconEntry(text: "中文", pinyin: "zhongwen", frequency: 12_000),
            LexiconEntry(text: "拼音", pinyin: "pinyin", frequency: 11_500),
            LexiconEntry(text: "输入法", pinyin: "shurufa", frequency: 11_000),
            LexiconEntry(text: "键盘", pinyin: "jianpan", frequency: 10_000),
            LexiconEntry(text: "测试", pinyin: "ceshi", frequency: 9_500),
            LexiconEntry(text: "我们", pinyin: "women", frequency: 11_000),
            LexiconEntry(text: "是", pinyin: "shi", frequency: 10_500),
            LexiconEntry(text: "的", pinyin: "de", frequency: 18_000),
            LexiconEntry(text: "在", pinyin: "zai", frequency: 16_000),
            LexiconEntry(text: "可以", pinyin: "keyi", frequency: 10_000),
            LexiconEntry(text: "请", pinyin: "qing", frequency: 8_000),
            LexiconEntry(text: "再见", pinyin: "zaijian", frequency: 10_000),
            LexiconEntry(text: "早上好", pinyin: "zaoshanghao", frequency: 9_000)
        ]
    }

    public func candidates(for input: String, limit: Int = 20) -> [PinyinCandidate] {
        guard limit > 0 else {
            return []
        }

        let query = normalize(input)
        guard !query.isEmpty else {
            return []
        }

        let segmentationLength = bestSegmentation(for: query)?.count ?? 0
        let matches = entries
            .filter { $0.pinyin.hasPrefix(query) || query.hasPrefix($0.pinyin) }
            .map { entry in
                let exactBonus = entry.pinyin == query ? 1_000_000 : 0
                let consumedLength = query.hasPrefix(entry.pinyin)
                    ? entry.pinyin.count
                    : 0
                let segmentationBonus = segmentationLength * 5
                let score = entry.frequency + exactBonus + consumedLength * 100 + segmentationBonus
                return (entry, score, consumedLength, entry.pinyin == query)
            }
            .sorted { left, right in
                if left.3 != right.3 {
                    return left.3
                }
                if left.2 != right.2 {
                    return left.2 > right.2
                }
                if left.0.frequency != right.0.frequency {
                    return left.0.frequency > right.0.frequency
                }
                return left.0.text < right.0.text
            }

        return matches.prefix(limit).enumerated().map { offset, value in
            PinyinCandidate(
                text: value.0.text,
                pinyin: value.0.pinyin,
                frequency: value.0.frequency,
                score: value.1,
                rank: offset + 1
            )
        }
    }

    public func isValidInputPrefix(_ input: String) -> Bool {
        let normalized = normalize(input)
        guard normalized == input else {
            return false
        }
        guard !normalized.isEmpty else {
            return true
        }

        let characters = Array(normalized)
        var memo: [Int: Bool] = [:]
        return canParsePrefix(characters, from: 0, memo: &memo)
    }

    public func bestSegmentation(for input: String) -> [String]? {
        let normalized = normalize(input)
        guard normalized == input, !normalized.isEmpty else {
            return normalized.isEmpty ? [] : nil
        }

        let characters = Array(normalized)
        var best: [[String]?] = Array(repeating: nil, count: characters.count + 1)
        best[0] = []

        for start in 0..<characters.count {
            guard let prefix = best[start] else {
                continue
            }

            for end in (start + 1)...characters.count {
                let token = String(characters[start..<end])
                guard Self.legalSyllables.contains(token) else {
                    continue
                }

                let candidate = prefix + [token]
                if let current = best[end] {
                    if candidate.count < current.count {
                        best[end] = candidate
                    }
                } else {
                    best[end] = candidate
                }
            }
        }

        return best[characters.count]
    }

    private func canParsePrefix(
        _ characters: [Character],
        from index: Int,
        memo: inout [Int: Bool]
    ) -> Bool {
        if index == characters.count {
            return true
        }
        if let cached = memo[index] {
            return cached
        }

        if index < characters.count {
            for end in (index + 1)...characters.count {
                let token = String(characters[index..<end])
                guard Self.legalSyllables.contains(token) else {
                    continue
                }
                if canParsePrefix(characters, from: end, memo: &memo) {
                    memo[index] = true
                    return true
                }
            }
        }

        let trailing = String(characters[index..<characters.count])
        if Self.legalSyllables.contains(where: { $0.hasPrefix(trailing) }) {
            memo[index] = true
            return true
        }

        memo[index] = false
        return false
    }

    private func normalize(_ input: String) -> String {
        input
            .lowercased()
            .unicodeScalars
            .filter { scalar in
                scalar.value >= 97 && scalar.value <= 122
            }
            .map(String.init)
            .joined()
    }
}
