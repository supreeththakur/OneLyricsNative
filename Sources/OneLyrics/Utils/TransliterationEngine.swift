import Foundation

enum DetectedLanguage: String {
    case hindi = "Hindi"
    case kannada = "Kannada"
    case unknown = "Unknown"
}

class TransliterationEngine {
    static let shared = TransliterationEngine()
    
    func detectLanguage(text: String) -> DetectedLanguage {
        let hindiRegex = try! NSRegularExpression(pattern: "[\\u0900-\\u097F]")
        let kannadaRegex = try! NSRegularExpression(pattern: "[\\u0C80-\\u0CFF]")
        
        let range = NSRange(location: 0, length: text.utf16.count)
        if hindiRegex.firstMatch(in: text, options: [], range: range) != nil {
            return .hindi
        } else if kannadaRegex.firstMatch(in: text, options: [], range: range) != nil {
            return .kannada
        }
        return .unknown
    }
    
    func transliterate(text: String) -> String {
        // Split by words/whitespace to preserve mixed languages
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let newWords = words.map { word -> String in
            let lang = detectLanguage(text: word)
            if lang == .hindi {
                return transliterateHindiWord(word)
            } else if lang == .kannada {
                return transliterateKannadaWord(word)
            }
            return word
        }
        
        // Restore newlines and whitespaces
        var result = ""
        var wordIndex = 0
        var currentWord = ""
        
        for scalar in text.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                if !currentWord.isEmpty {
                    result += newWords[wordIndex]
                    wordIndex += 1
                    currentWord = ""
                }
                result += String(scalar)
            } else {
                currentWord.append(Character(scalar))
            }
        }
        if !currentWord.isEmpty {
            result += newWords[wordIndex]
        }
        
        return result
    }
    
    // MARK: - Hindi Transliteration (Advanced)
    private func transliterateHindiWord(_ word: String) -> String {
        var w = word
        // Pre-replacements for multi-character conjuncts
        let preReplacements: [(String, String)] = [
            ("ज्ञ", "gy"), ("क्ष", "ksh"), ("त्र", "tr")
        ]
        for (k, v) in preReplacements {
            w = w.replacingOccurrences(of: k, with: v)
        }
        
        var out = ""
        let chars = Array(w.unicodeScalars).map { Character($0) }
        var i = 0
        
        // Basic mapping
        let consonants: [Character: String] = [
            "क": "k", "ख": "kh", "ग": "g", "घ": "gh", "ङ": "ng",
            "च": "ch", "छ": "chh", "ज": "j", "झ": "jh", "ञ": "ny",
            "ट": "t", "ठ": "th", "ड": "d", "ढ": "dh", "ण": "n",
            "त": "t", "थ": "th", "द": "d", "ध": "dh", "न": "n",
            "प": "p", "फ": "f", "ब": "b", "भ": "bh", "म": "m",
            "य": "y", "र": "r", "ल": "l", "व": "v", "श": "sh",
            "ष": "sh", "स": "s", "ह": "h",
            
            "क़": "q", "ख़": "kh", "ग़": "g", "ज़": "z",
            "ड़": "d", "ढ़": "dh", "फ़": "f", "य़": "y",
            
            "q": "q", "z": "z", "f": "f"
        ]
        
        let nuktaConsonants: [Character: String] = [
            "क": "q", "ख": "kh", "ग": "g", "ज": "z", "फ": "f", "ड": "d", "ढ": "dh"
        ]
        
        let independentVowels: [Character: String] = [
            "अ": "a", "आ": "aa", "इ": "i", "ई": "ee", "उ": "u", "ऊ": "oo",
            "ए": "e", "ऐ": "ai", "ओ": "o", "औ": "au", "ऋ": "ri"
        ]
        
        let dependentVowels: [Character: String] = [
            "ा": "aa", "ि": "i", "ी": "ee", "ु": "u", "ू": "oo",
            "े": "e", "ै": "ai", "ो": "o", "ौ": "au", "ृ": "ri"
        ]
        
        while i < chars.count {
            let c = chars[i]
            
            var currentConsStr: String? = nil
            
            if i + 1 < chars.count && chars[i+1] == "़" { // Nukta check
                if let nCons = nuktaConsonants[c] {
                    currentConsStr = nCons
                    i += 1 // Advance past the nukta
                }
            }
            
            if currentConsStr == nil {
                currentConsStr = consonants[c]
            }
            
            if let indV = independentVowels[c] {
                out += indV
            } else if let cons = currentConsStr {
                out += cons
                // Check if schwa is needed
                let nextC = i + 1 < chars.count ? chars[i+1] : nil
                let nextNextC = i + 2 < chars.count ? chars[i+2] : nil
                
                var hasVowelSign = false
                var isHalant = false
                
                if let next = nextC {
                    if dependentVowels[next] != nil {
                        hasVowelSign = true
                    } else if next == "्" { // Halant
                        isHalant = true
                    } else if next == "ं" || next == "ँ" {
                        // Anusvara/Chandrabindu - vowel still exists
                    }
                }
                
                if !hasVowelSign && !isHalant {
                    // Schwa deletion rule
                    var deleteSchwa = false
                    if i == chars.count - 1 {
                        deleteSchwa = true
                    } else if i > 0 && i < chars.count - 2 {
                        // Schwa deletion in the middle of a word (e.g. Karta -> Kar-ta instead of Karata)
                        if let n1 = nextC, consonants[n1] != nil || n1 == "़" { 
                            if let n2 = nextNextC, dependentVowels[n2] != nil || n2 == "ा" {
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
            } else if c == "ं" || c == "ँ" {
                if i + 1 < chars.count {
                    let nextC = chars[i+1]
                    if ["प", "फ", "ब", "भ", "म"].contains(nextC) {
                        out += "m"
                    } else {
                        out += "n"
                    }
                } else {
                    out += "n"
                }
            } else if c == "्" {
                // Halant - do nothing, it prevents schwa
            } else if c == "ऽ" {
                // Avagraha
                out += "a"
            } else if c != "़" { 
                // Orphaned nukta that didn't match a consonant above
                out += String(c)
            }
            i += 1
        }
        
        // Post-processing for common Hinglish aesthetics
        out = out.replacingOccurrences(of: "iaa", with: "iya")
        out = out.replacingOccurrences(of: "uaa", with: "uwa")
        if out.hasSuffix("aa") && out.count > 2 {
            // Keep aa
        }
        
        // Capitalize first letter
        if out.count > 0 {
            out = out.prefix(1).capitalized + out.dropFirst()
        }
        
        return out
    }
    
    // MARK: - Kannada Transliteration (Advanced)
    private func transliterateKannadaWord(_ word: String) -> String {
        var out = ""
        let chars = Array(word.unicodeScalars).map { Character($0) }
        var i = 0
        
        let consonants: [Character: String] = [
            "ಕ": "k", "ಖ": "kh", "ಗ": "g", "ಘ": "gh", "ಙ": "ng",
            "ಚ": "ch", "ಛ": "chh", "ಜ": "j", "ಝ": "jh", "ಞ": "ny",
            "ಟ": "t", "ಠ": "th", "ಡ": "d", "ಢ": "dh", "ಣ": "n",
            "ತ": "t", "ಥ": "th", "ದ": "d", "ಧ": "dh", "ನ": "n",
            "ಪ": "p", "ಫ": "f", "ಬ": "b", "ಭ": "bh", "ಮ": "m",
            "ಯ": "y", "ರ": "r", "ಲ": "l", "ವ": "v", "ಶ": "sh",
            "ಷ": "sh", "ಸ": "s", "ಹ": "h", "ಳ": "l"
        ]
        
        let independentVowels: [Character: String] = [
            "ಅ": "a", "ಆ": "aa", "ಇ": "i", "ಈ": "ee", "ಉ": "u", "ಊ": "oo",
            "ಋ": "ru", "ಎ": "e", "ಏ": "ea", "ಐ": "ai", "ಒ": "o", "ಓ": "oa", "ಔ": "au"
        ]
        
        let dependentVowels: [Character: String] = [
            "ಾ": "aa", "ಿ": "i", "ೀ": "ee", "ು": "u", "ೂ": "oo",
            "ೃ": "ru", "ೆ": "e", "ೇ": "ea", "ೈ": "ai", "ೊ": "o", "ೋ": "oa", "ೌ": "au"
        ]
        
        while i < chars.count {
            let c = chars[i]
            
            if let indV = independentVowels[c] {
                out += indV
            } else if let cons = consonants[c] {
                out += cons
                let nextC = i + 1 < chars.count ? chars[i+1] : nil
                
                var hasVowelSign = false
                var isHalant = false
                
                if let next = nextC {
                    if dependentVowels[next] != nil {
                        hasVowelSign = true
                    } else if next == "್" { // Virama
                        isHalant = true
                    }
                }
                
                if !hasVowelSign && !isHalant {
                    out += "a" // Kannada inherent vowel is 'a'
                }
            } else if let depV = dependentVowels[c] {
                out += depV
            } else if c == "ಂ" { // Anusvara
                if i + 1 < chars.count {
                    let nextC = chars[i+1]
                    if ["ಪ", "ಫ", "ಬ", "ಭ", "ಮ"].contains(nextC) {
                        out += "m"
                    } else {
                        out += "n"
                    }
                } else {
                    out += "m"
                }
            } else if c == "ಃ" { // Visarga
                out += "h"
            } else if c == "್" {
                // Virama - do nothing
            } else {
                out += String(c)
            }
            i += 1
        }
        
        // Capitalize first letter
        if out.count > 0 {
            out = out.prefix(1).capitalized + out.dropFirst()
        }
        
        return out
    }
}
