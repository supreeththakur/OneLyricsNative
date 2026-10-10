import Foundation

func transliteratePunjabiWord(_ word: String) -> String {
    var out = ""
    let chars = Array(word.unicodeScalars).map { Character($0) }
    var i = 0
    
    let consonants: [Character: String] = [
        "ਕ": "k", "ਖ": "kh", "ਗ": "g", "ਘ": "gh", "ਙ": "ng",
        "ਚ": "ch", "ਛ": "chh", "ਜ": "j", "ਝ": "jh", "ਞ": "ny",
        "ਟ": "t", "ਠ": "th", "ਡ": "d", "ਢ": "dh", "ਣ": "n",
        "ਤ": "t", "ਥ": "th", "ਦ": "d", "ਧ": "dh", "ਨ": "n",
        "ਪ": "p", "ਫ": "ph", "ਬ": "b", "ਭ": "bh", "ਮ": "m",
        "ਯ": "y", "ਰ": "r", "ਲ": "l", "ਵ": "v",
        "ਸ": "s", "ਹ": "h",
        
        "ਸ਼": "sh", "ਖ਼": "kh", "ਗ਼": "g", "ਜ਼": "z", "ੜ": "r", "ਫ਼": "f",
        "q": "q", "z": "z", "f": "f"
    ]
    
    let nuktaConsonants: [Character: String] = [
        "ਸ": "sh", "ਖ": "kh", "ਗ": "g", "ਜ": "z", "ਫ": "f", "ਡ": "r"
    ]
    
    let independentVowels: [Character: String] = [
        "ਅ": "a", "ਆ": "aa", "ਇ": "i", "ਈ": "i", "ਉ": "u", "ਊ": "u",
        "ਏ": "e", "ਐ": "ae", "ਓ": "o", "ਔ": "au"
    ]
    
    let dependentVowels: [Character: String] = [
        "ਾ": "aa", "ਿ": "i", "ੀ": "i", "ੁ": "u", "ੂ": "u",
        "ੇ": "e", "ੈ": "ai", "ੋ": "o", "ੌ": "au"
    ]
    
    while i < chars.count {
        let c = chars[i]
        
        var currentConsStr: String? = nil
        
        if i + 1 < chars.count && chars[i+1] == "਼" {
            if let nCons = nuktaConsonants[c] {
                currentConsStr = nCons
                i += 1
            }
        }
        
        if currentConsStr == nil {
            currentConsStr = consonants[c]
        }
        
        if let indV = independentVowels[c] {
            out += indV
        } else if let cons = currentConsStr {
            out += cons
            
            let nextC = i + 1 < chars.count ? chars[i+1] : nil
            let nextNextC = i + 2 < chars.count ? chars[i+2] : nil
            
            var hasVowelSign = false
            var isHalant = false
            
            if let next = nextC {
                if dependentVowels[next] != nil {
                    hasVowelSign = true
                } else if next == "੍" {
                    isHalant = true
                } else if next == "ਂ" || next == "ੰ" || next == "ੱ" {
                    // Bindi, Tippi, Adhak don't negate schwa fully, wait, Adhak means doubling next cons, so it acts like a halant for the current? No, Adhak means the current syllable is short. Vowel is already there.
                    // Wait, if it's "k" + "adhak", the "a" schwa is needed. "k" -> "ka", adhak -> "t" -> "kat". So schwa is still needed!
                    // Wait! A Punjabi consonant without a vowel sign HAS a schwa. "ਕ" is "ka". "ਕੱ" is "ka" + double next.
                }
            }
            
            if !hasVowelSign && !isHalant {
                var deleteSchwa = false
                if i == chars.count - 1 {
                    deleteSchwa = true
                } else if i > 0 && i < chars.count - 2 {
                    if let n1 = nextC, (consonants[n1] != nil || n1 == "਼" || n1 == "ੱ") {
                        if let n2 = nextNextC, dependentVowels[n2] != nil || n2 == "ਾ" {
                            deleteSchwa = true
                        }
                    }
                }
                
                if !deleteSchwa {
                    out += "a"
                }
            }
        } else if let depV = dependentVowels[c] {
            out += depV
        } else if c == "ਂ" || c == "ੰ" { // Bindi or Tippi
            // In romanized Punjabi, "Mainu" instead of "Mainun" is common. If it's at the end of a word, maybe drop it?
            // "ਮੈਨੂੰ" ends in Tippi/Bindi. ੂ is "u", ੰ is "n". "Mainun".
            // Let's just output "n" for now, post-processing will strip "n" if it's "un" at the end.
            if i + 1 < chars.count {
                let nextC = chars[i+1]
                if ["ਪ", "ਫ", "ਬ", "ਭ", "ਮ"].contains(nextC) {
                    out += "m"
                } else {
                    out += "n"
                }
            } else {
                out += "n"
            }
        } else if c == "ੱ" { // Adhak
            if i + 1 < chars.count {
                let nextC = chars[i+1]
                if let nextCons = consonants[nextC] {
                    if let firstChar = nextCons.first {
                        out += String(firstChar)
                    }
                }
            }
        } else if c == "੍" {
            // Halant
        } else if c != "਼" {
            out += String(c)
        }
        i += 1
    }
    
    // Post-processing
    out = out.replacingOccurrences(of: "iaa", with: "iya")
    out = out.replacingOccurrences(of: "uaa", with: "uwa")
    
    // Drop terminal 'n' after 'u' for words like mainu, tenu, sanu
    if out.hasSuffix("un") {
        out = String(out.dropLast())
    }
    
    if out.count > 0 {
        out = out.prefix(1).capitalized + out.dropFirst()
    }
    
    return out
}

let text = "ਮੇਰਾ ਆਪਣਾ ਨਾ ਮੇਰਾ ਕਦੇ ਹੋਇਆ"
let punjabiRegex = try! NSRegularExpression(pattern: "[\\u0A00-\\u0A7F]")
let range = NSRange(location: 0, length: text.utf16.count)
if punjabiRegex.firstMatch(in: text, options: [], range: range) != nil {
    print("Detected: Punjabi")
} else {
    print("Detected: Unknown")
}
print("Result:", transliteratePunjabiWord(text))
print("Result:", transliteratePunjabiWord("ਕਰਦੀ")) // Kardi
print("Result:", transliteratePunjabiWord("ਐ")) // Ae
print("Result:", transliteratePunjabiWord("ਮੈਨੂੰ")) // Mainu
print("Result:", transliteratePunjabiWord("ਕੁੱਤਾ")) // Kutta
