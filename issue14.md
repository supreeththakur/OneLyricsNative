AUTO LYRICS TRANSLITERATION

Add an automatic lyrics transliteration feature to OneLyrics.

Whenever lyrics are imported or entered, automatically detect the script/language of the lyrics.

Currently support:

1. Hindi → Hinglish / Roman Hindi
2. Kannada → Roman Kannada

The system must automatically detect whether the lyrics are written in Hindi Devanagari or Kannada script.

If Hindi lyrics are detected:
Automatically convert the lyrics from Devanagari Hindi into natural Roman Hindi / Hinglish.

Example:

Original:
तू ही है मेरी दुनिया

Output:
Tu hi hai meri duniya

If Kannada lyrics are detected:
Automatically convert Kannada script into natural Roman Kannada.

Example:

Original:
ನೀನು ನನ್ನ ಪ್ರೀತಿ

Output:
Neenu nanna preeti

IMPORTANT:
This is TRANSLITERATION, not translation.

Do NOT translate the meaning into another language.

The meaning, pronunciation, wording, line structure and emotional context of the original lyrics must remain unchanged.

The system should generate natural, readable Roman-script lyrics rather than mechanical character-by-character transliteration.

Handle correctly:

- Long and short vowels
- Consonant combinations
- Half letters
- Nasal sounds
- Anusvara
- Visarga
- Aspirated consonants
- Double consonants
- Common pronunciation patterns
- Word boundaries
- Natural pronunciation
- Common Hindi words
- Common Kannada words
- Song-specific pronunciation

Examples:

Hindi:
मैं तेरा हूँ

Correct:
Main tera hoon

Hindi:
क्यों इतना प्यार किया

Correct:
Kyun itna pyaar kiya

Kannada:
ನನ್ನ ಹೃದಯ ನಿನ್ನದು

Correct:
Nanna hrudaya ninnadu

The system must preserve the original lyric line breaks.

Example:

Original:

तू मेरा है
तू मेरा था
तू मेरा रहेगा

Output:

Tu mera hai
Tu mera tha
Tu mera rahega

Do not merge or rearrange lyric lines.

--------------------------------------------------

AUTOMATIC DETECTION

Whenever lyrics are entered/imported:

1. Detect the script.
2. Identify Hindi Devanagari or Kannada script.
3. Automatically select the appropriate transliteration engine.
4. Generate the Roman-script version.
5. Display the result immediately.

If the lyrics are already written in Roman script:

Do not transliterate them again.

Example:

Input:
Tum hi ho meri duniya

Output:
Tum hi ho meri duniya

--------------------------------------------------

MIXED LYRICS

Handle mixed-script lyrics intelligently.

Example:

तू मेरा है baby
ನೀನು ನನ್ನ love

The system should process each segment according to its detected script while preserving existing Roman words.

Expected:

Tu mera hai baby
Neenu nanna love

--------------------------------------------------

USER CONTROL

Provide an automatic toggle:

Auto Transliteration: ON / OFF

When ON:
Lyrics are automatically transliterated whenever Hindi or Kannada script is detected.

When OFF:
Keep the original lyrics unchanged.

Also provide:

Original Lyrics
Transliterated Lyrics

Allow the user to switch between them.

--------------------------------------------------

MANUAL EDITING

The generated transliteration must always remain editable.

The user should be able to correct individual words without changing the original lyrics.

Example:

Generated:
Main tumse pyar karta hoon

User edits:
Main tumse pyaar karta hoon

Save the edited version separately.

Never overwrite the original lyrics.

--------------------------------------------------

LYRIC TIMING COMPATIBILITY

The transliterated lyrics must remain connected to the same lyric timing data.

If the original lyric has:

Line 1 → 00:12.500
Line 2 → 00:15.200

After transliteration:

Line 1 → 00:12.500
Line 2 → 00:15.200

Timing must not be lost or reset.

Word-level timing should also remain attached to the corresponding words whenever possible.

--------------------------------------------------

QUALITY REQUIREMENT

Do not use simple character replacement rules as the primary transliteration system.

Use a proper Indic-language transliteration engine/model capable of handling Hindi and Kannada naturally.

The architecture must allow additional Indian languages to be added later without rewriting the lyrics system.

Future languages may include:

Punjabi
Bengali
Marathi
Telugu
Tamil
Malayalam
Gujarati

For now, implement only:

Hindi → Hinglish
Kannada → Roman Kannada

The final experience should feel automatic:

Import Lyrics
→ Detect Language
→ Detect Script
→ Transliterate
→ Show Roman Lyrics
→ Allow Editing
→ Preserve Timing
→ Use Transliteration in Final Lyric Video
