import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class AssamesePhoneticsService {
  // ─── 1. IRREGULAR PRONUNCIATION LEXICON ──────────────────────────────
  static const Map<String, List<String>> lexicon = {
    // Word: [Phonetic representation for TTS, IPA notation]
    "অসম": ["অখম", "ɔ.xɔm"],
    "অসমীয়া": ["অখমীয়া", "ɔ.xɔ.mi.ja"],
    "অসমৰ": ["অখমৰ", "ɔ.xɔ.mɔɹ"],
    "নমস্কাৰ": ["নম'খকাৰ", "nɔ.mɔx.kaɹ"],
    "ধন্যবাদ": ["ধইন্নোবাদ", "dʱɔin.no.bad"],
    "সহায়": ["খহায়", "xɔ.haj"],
    "সাহায্য": ["খাহাইজ্য", "xa.haiz.jɔ"],
    "শিক্ষক": ["খিকখক", "xik.xɔk"],
    "শিক্ষা": ["খিকখা", "xik.xa"],
    "বিজ্ঞান": ["বিগ্গ্যান", "big.gjan"],
    "বৈজ্ঞানিক": ["বইগ্গ্যানিক", "bɔi.gja.nik"],
    "স্বাস্থ্য": ["স্থাচ্ছ", "stʰas.sɔ"],
    "চাহ": ["সাহ", "sah"],
    "মাছ": ["মাচ", "mas"],
    "জলপান": ["জ়লপান", "zɔl.pan"],
    "যোৰহাট": ["জ়োৰহাট", "zoɹ.hat"],
    "গুৱাহাটী": ["গুৱাহাটি", "gu.wa.ha.ti"],
    "ডিব্ৰুগড়": ["ডিব্ৰুগৰ", "di.bɹu.gɔɹ"],
    "তেজপুৰ": ["তেজ়পুৰ", "tez.puɹ"],
    "শিলচৰ": ["খিলচৰ", "xil.sɔɹ"],
    "ব্ৰহ্মপুত্ৰ": ["ব্ৰম্মোপুত্ত্ৰ", "bɹɔm.mo.put.tɹɔ"],
    "ইতিহাস": ["ইতিহাখ", "i.ti.hax"],
    "সংস্কৃতি": ["খংক্ৰিতি", "xɔŋ.kɹi.ti"],
    "ভাষা": ["ভাখা", "bʱa.xa"],
    "সাহিত্য": ["খাহিত্য", "xa.hit.tɔ"],
    "মানুহ": ["মানু", "ma.nuh"],
    "প্ৰশ্ন": ["প্ৰস্ন্ন", "pɹɔs.nɔ"],
    "উত্তৰ": ["উত্তৰ", "ut.tɔɹ"],
    "পৰীক্ষা": ["পৰিকখা", "pɔ.ɹik.xa"],
    "প্ৰধানমন্ত্ৰী": ["প্ৰধানমোন্ত্ৰী", "pɹɔ.dʱan.mɔn.tɹi"],
    "মুখ্যমন্ত্ৰী": ["মুখখোমোন্ত্ৰী", "mukʰ.kʰo.mɔn.tɹi"],
    "সৰ্বোচ্চ": ["খৰ্বোচ্চ", "xɔɹ.bos.sɔ"],
    "উচ্চতম": ["উচ্চতম্", "us.sɔ.tɔm"],
    "স্থান": ["স্থান", "stʰan"],
    "বিশেষ": ["বিখেখ", "bi.xex"],
    "সদস্য": ["খদইস্য", "xɔ.dɔis.sɔ"],
    "প্ৰশাসন": ["প্ৰখাখন", "pɹɔ.xa.xɔn"],
    "সমাজ": ["খমাজ", "xɔ.maz"],
    "সংবাদ": ["খংবাদ", "xɔŋ.bad"],
    "বাতৰি": ["বাতৰি", "ba.tɔ.ɹi"],
    "দেশ": ["দেখ", "dex"],
    "শান্তি": ["খান্তি", "xan.ti"],
    "শুভ": ["খুভ", "xu.bʱɔ"],
    "সফল": ["খফল", "xɔ.pʰɔl"],
    "জীৱন": ["জ়ীৱন", "zi.wɔn"],
    "জগত": ["জ়গত", "zɔ.gɔt"],
    "সূৰ্য": ["খুৰ্জ", "xuɹ.zɔ"],
    "সুন্দৰ": ["খুন্দৰ", "xun.dɔɹ"],
    "মৰম": ["মৰম", "mɔ.ɹɔm"],
    "ভালপোৱা": ["ভালপোৱা", "bʱal.po.wa"],
    "সঁচা": ["খঁচা", "xɔ̃.sa"],
    "মিছা": ["মিছা", "mi.sa"],
    "সময়": ["খময়", "xɔ.mɔj"],
    "সন্ধিয়া": ["খন্ধিয়া", "xɔn.dʱi.ja"],
    "ৰাতিপুৱা": ["ৰাতিপুৱা", "ɹa.ti.pu.wa"],
  };

  // ─── 2. G2P PHONETIC TRANSFORMATION ──────────────────────────────────
  static String toPhoneticScript(String text) {
    if (text.isEmpty) return text;

    // 1. Lexicon substitution
    final words = text.split(' ');
    final resultWords = <String>[];

    for (final word in words) {
      final clean = word.replaceAll(RegExp(r'[।,\.\?!—\-\(\)]'), '').replaceAll("'", '').replaceAll('"', '');
      if (lexicon.containsKey(clean)) {
        final phonetic = lexicon[clean]![0];
        resultWords.add(word.replaceAll(clean, phonetic));
      } else {
        resultWords.add(word);
      }
    }

    var result = resultWords.join(' ');

    // 2. Protect Sibilant Clusters (স্ত, স্থ, স্ক, স্প)
    result = result.replaceAllMapped(
      RegExp(r'([শষস])্([তথকপফট])'),
      (m) => 'স্${m.group(2)}',
    );

    // 3. Lone Sibilants -> 'খ' (/x/ sound)
    result = result.replaceAllMapped(
      RegExp(r'\b[শষস]([ািীুূৃেৈোৌ্]?)'),
      (m) => 'খ${m.group(1)}',
    );

    // 4. Script standardization: Bengali 'র' -> Assamese 'ৰ'
    result = result.replaceAll('\u09b0', '\u09f0');

    return result;
  }

  // ─── 3. IPA NOTATION GENERATOR ──────────────────────────────────────
  static String toIPA(String text) {
    if (text.isEmpty) return text;

    const ipaMap = {
      'অ': 'ɔ', 'আ': 'a', 'ই': 'i', 'ঈ': 'i', 'উ': 'u', 'ঊ': 'u', 'ঋ': 'ɹi',
      'এ': 'e', 'ঐ': 'ɔi', 'ও': 'o', 'ঔ': 'ɔu',
      'ক': 'k', 'খ': 'kʰ', 'গ': 'g', 'ঘ': 'gʱ', 'ঙ': 'ŋ',
      'চ': 's', 'ছ': 's', 'জ': 'z', 'ঝ': 'zʱ', 'ঞ': 'ɲ',
      'ট': 't', 'ঠ': 'tʰ', 'ড': 'd', 'ঢ': 'dʱ', 'ণ': 'n',
      'ত': 't', 'থ': 'tʰ', 'দ': 'd', 'ধ': 'dʱ', 'ন': 'n',
      'প': 'p', 'ফ': 'pʰ', 'ব': 'b', 'ভ': 'bʱ', 'ম': 'm',
      'য': 'z', 'ৰ': 'ɹ', 'ল': 'l', 'ৱ': 'w',
      'শ': 'x', 'ষ': 'x', 'স': 'x', 'হ': 'h',
      'ক্ষ': 'kʰjɔ', 'জ্ঞ': 'gjan', 'ড়': 'ɹ', 'ঢ়': 'ɹʱ', 'য়': 'j',
      'ৎ': 't', 'ং': 'ŋ', 'ঃ': 'h', 'ঁ': '̃',
      'া': 'a', 'ি': 'i', 'ী': 'i', 'ু': 'u', 'ূ': 'u', 'ৃ': 'ɹi',
      'ে': 'e', 'ৈ': 'ɔi', 'ো': 'o', 'ৌ': 'ɔu', '্': ''
    };

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ipaMap.containsKey(ch)) {
        buffer.write(ipaMap[ch]);
      } else {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  // ─── 4. SYNTHESIZE SPEECH VIA BACKEND ──────────────────────────────
  static Future<Map<String, dynamic>> synthesizeSpeech({
    required String text,
    String voice = 'asm_female',
    double speed = 1.0,
  }) async {
    try {
      final baseUrl = await StorageService.loadApiBaseUrl();
      final url = Uri.parse('$baseUrl/api/chat/tts/');

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'voice': voice,
          'speed': speed,
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else {
        // Local phonetic fallback
        return {
          'success': true,
          'phonetic_text': toPhoneticScript(text),
          'ipa': toIPA(text),
          'engine': 'client_phonetic_engine',
        };
      }
    } catch (_) {
      return {
        'success': true,
        'phonetic_text': toPhoneticScript(text),
        'ipa': toIPA(text),
        'engine': 'client_phonetic_engine',
      };
    }
  }
}
