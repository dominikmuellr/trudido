/// Service for providing localized greetings based on time and language preference
class GreetingService {
  // Multilingual greetings for different times of day
  static const List<Map<String, dynamic>> _greetings = [
    // English
    {
      'morning': 'Good morning',
      'afternoon': 'Good afternoon',
      'evening': 'Good evening',
      'night': 'Good night',
      'morningSubtitle': 'Ready to tackle your morning tasks?',
      'afternoonSubtitle': 'How\'s your day going so far?',
      'eveningSubtitle': 'Time to wrap up the day!',
      'nightSubtitle': 'What\'s on your mind?',
      'notesMorningSubtitle': 'Capture your morning thoughts',
      'notesAfternoonSubtitle': 'Ready to capture ideas?',
      'notesEveningSubtitle': 'Evening thoughts?',
      'notesNightSubtitle': 'What\'s on your mind?',
    },
    // Español
    {
      'morning': 'Buenos días',
      'afternoon': 'Buenas tardes',
      'evening': 'Buenas tardes',
      'night': 'Buenas noches',
      'morningSubtitle': '¿Listo para las tareas matutinas?',
      'afternoonSubtitle': '¿Cómo va tu día?',
      'eveningSubtitle': '¡Hora de terminar el día!',
      'nightSubtitle': '¿Qué tienes en mente?',
      'notesMorningSubtitle': 'Captura tus pensamientos matutinos',
      'notesAfternoonSubtitle': '¿Listo para capturar ideas?',
      'notesEveningSubtitle': '¿Pensamientos vespertinos?',
      'notesNightSubtitle': '¿Qué tienes en mente?',
    },
    // Français
    {
      'morning': 'Bonjour',
      'afternoon': 'Bon après-midi',
      'evening': 'Bonsoir',
      'night': 'Bonne nuit',
      'morningSubtitle': 'Prêt à affronter vos tâches matinales?',
      'afternoonSubtitle': 'Comment se passe votre journée?',
      'eveningSubtitle': 'Il est temps de terminer la journée!',
      'nightSubtitle': 'Qu\'avez-vous en tête?',
      'notesMorningSubtitle': 'Capturez vos pensées matinales',
      'notesAfternoonSubtitle': 'Prêt à capturer des idées?',
      'notesEveningSubtitle': 'Pensées du soir?',
      'notesNightSubtitle': 'Qu\'avez-vous en tête?',
    },
    // Deutsch
    {
      'morning': 'Guten Morgen',
      'afternoon': 'Guten Tag',
      'evening': 'Guten Abend',
      'night': 'Gute Nacht',
      'morningSubtitle': 'Bereit für die Morgenaufgaben?',
      'afternoonSubtitle': 'Wie läuft dein Tag?',
      'eveningSubtitle': 'Zeit, den Tag abzuschließen!',
      'nightSubtitle': 'Was denkst du?',
      'notesMorningSubtitle': 'Erfasse deine Morgengedanken',
      'notesAfternoonSubtitle': 'Bereit, Ideen festzuhalten?',
      'notesEveningSubtitle': 'Abendgedanken?',
      'notesNightSubtitle': 'Was denkst du?',
    },
    // Italiano
    {
      'morning': 'Buongiorno',
      'afternoon': 'Buon pomeriggio',
      'evening': 'Buonasera',
      'night': 'Buonanotte',
      'morningSubtitle': 'Pronto ad affrontare le attività mattutine?',
      'afternoonSubtitle': 'Come sta andando la giornata?',
      'eveningSubtitle': 'Ora di concludere la giornata!',
      'nightSubtitle': 'A cosa stai pensando?',
      'notesMorningSubtitle': 'Cattura i tuoi pensieri mattutini',
      'notesAfternoonSubtitle': 'Pronto a catturare idee?',
      'notesEveningSubtitle': 'Pensieri serali?',
      'notesNightSubtitle': 'A cosa stai pensando?',
    },
    // Nederlands
    {
      'morning': 'Goedemorgen',
      'afternoon': 'Goedemiddag',
      'evening': 'Goedenavond',
      'night': 'Goedenacht',
      'morningSubtitle': 'Klaar voor de ochtendtaken?',
      'afternoonSubtitle': 'Hoe gaat je dag?',
      'eveningSubtitle': 'Tijd om de dag af te sluiten!',
      'nightSubtitle': 'Waar denk je aan?',
      'notesMorningSubtitle': 'Leg je ochtendgedachten vast',
      'notesAfternoonSubtitle': 'Klaar om ideeën vast te leggen?',
      'notesEveningSubtitle': 'Avondgedachten?',
      'notesNightSubtitle': 'Waar denk je aan?',
    },
    // Português
    {
      'morning': 'Bom dia',
      'afternoon': 'Boa tarde',
      'evening': 'Boa tarde',
      'night': 'Boa noite',
      'morningSubtitle': 'Pronto para as tarefas matinais?',
      'afternoonSubtitle': 'Como está seu dia?',
      'eveningSubtitle': 'Hora de encerrar o dia!',
      'nightSubtitle': 'No que você está pensando?',
      'notesMorningSubtitle': 'Capture seus pensamentos matinais',
      'notesAfternoonSubtitle': 'Pronto para capturar ideias?',
      'notesEveningSubtitle': 'Pensamentos noturnos?',
      'notesNightSubtitle': 'No que você está pensando?',
    },
    // Svenska
    {
      'morning': 'God morgon',
      'afternoon': 'God eftermiddag',
      'evening': 'God kväll',
      'night': 'God natt',
      'morningSubtitle': 'Redo för morgonuppgifterna?',
      'afternoonSubtitle': 'Hur går din dag?',
      'eveningSubtitle': 'Dags att avsluta dagen!',
      'nightSubtitle': 'Vad tänker du på?',
      'notesMorningSubtitle': 'Fånga dina morgontankar',
      'notesAfternoonSubtitle': 'Redo att fånga idéer?',
      'notesEveningSubtitle': 'Kvällstankar?',
      'notesNightSubtitle': 'Vad tänker du på?',
    },
    // Dansk
    {
      'morning': 'Godmorgen',
      'afternoon': 'God eftermiddag',
      'evening': 'God aften',
      'night': 'Godnat',
      'morningSubtitle': 'Klar til morgenopgaverne?',
      'afternoonSubtitle': 'Hvordan går din dag?',
      'eveningSubtitle': 'Tid til at afslutte dagen!',
      'nightSubtitle': 'Hvad tænker du på?',
      'notesMorningSubtitle': 'Fang dine morgentanker',
      'notesAfternoonSubtitle': 'Klar til at fange idéer?',
      'notesEveningSubtitle': 'Aftentanker?',
      'notesNightSubtitle': 'Hvad tænker du på?',
    },
    // Norsk
    {
      'morning': 'God morgen',
      'afternoon': 'God ettermiddag',
      'evening': 'God kveld',
      'night': 'God natt',
      'morningSubtitle': 'Klar for morgenoppgavene?',
      'afternoonSubtitle': 'Hvordan går dagen din?',
      'eveningSubtitle': 'Tid å avslutte dagen!',
      'nightSubtitle': 'Hva tenker du på?',
      'notesMorningSubtitle': 'Fang morgentankene dine',
      'notesAfternoonSubtitle': 'Klar til å fange ideer?',
      'notesEveningSubtitle': 'Kveldstanker?',
      'notesNightSubtitle': 'Hva tenker du på?',
    },
    // Suomi
    {
      'morning': 'Hyvää huomenta',
      'afternoon': 'Hyvää iltapäivää',
      'evening': 'Hyvää iltaa',
      'night': 'Hyvää yötä',
      'morningSubtitle': 'Valmis aamutehtäviin?',
      'afternoonSubtitle': 'Miten päiväsi sujuu?',
      'eveningSubtitle': 'Aika lopettaa päivä!',
      'nightSubtitle': 'Mitä mietit?',
      'notesMorningSubtitle': 'Tallenna aamuajatuksesi',
      'notesAfternoonSubtitle': 'Valmis tallentamaan ideoita?',
      'notesEveningSubtitle': 'Ilta-ajatuksia?',
      'notesNightSubtitle': 'Mitä mietit?',
    },
    // Polski
    {
      'morning': 'Dzień dobry',
      'afternoon': 'Dzień dobry',
      'evening': 'Dobry wieczór',
      'night': 'Dobranoc',
      'morningSubtitle': 'Gotowy na poranne zadania?',
      'afternoonSubtitle': 'Jak mija dzień?',
      'eveningSubtitle': 'Czas zakończyć dzień!',
      'nightSubtitle': 'O czym myślisz?',
      'notesMorningSubtitle': 'Zapisz swoje poranne myśli',
      'notesAfternoonSubtitle': 'Gotowy zapisać pomysły?',
      'notesEveningSubtitle': 'Wieczorne myśli?',
      'notesNightSubtitle': 'O czym myślisz?',
    },
    // Čeština
    {
      'morning': 'Dobré ráno',
      'afternoon': 'Dobré odpoledne',
      'evening': 'Dobrý večer',
      'night': 'Dobrou noc',
      'morningSubtitle': 'Připraven na ranní úkoly?',
      'afternoonSubtitle': 'Jak se daří?',
      'eveningSubtitle': 'Čas ukončit den!',
      'nightSubtitle': 'Na co myslíš?',
      'notesMorningSubtitle': 'Zachyť své ranní myšlenky',
      'notesAfternoonSubtitle': 'Připraven zachytit nápady?',
      'notesEveningSubtitle': 'Večerní myšlenky?',
      'notesNightSubtitle': 'Na co myslíš?',
    },
    // Magyar
    {
      'morning': 'Jó reggelt',
      'afternoon': 'Jó napot',
      'evening': 'Jó estét',
      'night': 'Jó éjszakát',
      'morningSubtitle': 'Készen a reggeli feladatokra?',
      'afternoonSubtitle': 'Hogy telik a napod?',
      'eveningSubtitle': 'Ideje befejezni a napot!',
      'nightSubtitle': 'Mire gondolsz?',
      'notesMorningSubtitle': 'Rögzítsd a reggeli gondolataid',
      'notesAfternoonSubtitle': 'Készen az ötletek rögzítésére?',
      'notesEveningSubtitle': 'Esti gondolatok?',
      'notesNightSubtitle': 'Mire gondolsz?',
    },
    // Română
    {
      'morning': 'Bună dimineața',
      'afternoon': 'Bună ziua',
      'evening': 'Bună seara',
      'night': 'Noapte bună',
      'morningSubtitle': 'Gata pentru sarcinile de dimineață?',
      'afternoonSubtitle': 'Cum îți merge ziua?',
      'eveningSubtitle': 'E timpul să închei ziua!',
      'nightSubtitle': 'La ce te gândești?',
      'notesMorningSubtitle': 'Captează gândurile tale de dimineață',
      'notesAfternoonSubtitle': 'Gata să capturezi idei?',
      'notesEveningSubtitle': 'Gânduri de seară?',
      'notesNightSubtitle': 'La ce te gândești?',
    },
    // Türkçe
    {
      'morning': 'Günaydın',
      'afternoon': 'İyi günler',
      'evening': 'İyi akşamlar',
      'night': 'İyi geceler',
      'morningSubtitle': 'Sabah görevlerine hazır mısın?',
      'afternoonSubtitle': 'Günün nasıl geçiyor?',
      'eveningSubtitle': 'Günü kapatma zamanı!',
      'nightSubtitle': 'Aklında ne var?',
      'notesMorningSubtitle': 'Sabah düşüncelerini yakala',
      'notesAfternoonSubtitle': 'Fikirleri yakalamaya hazır mısın?',
      'notesEveningSubtitle': 'Akşam düşünceleri?',
      'notesNightSubtitle': 'Aklında ne var?',
    },
    // Українська
    {
      'morning': 'Доброго ранку',
      'afternoon': 'Добрий день',
      'evening': 'Добрий вечір',
      'night': 'На добраніч',
      'morningSubtitle': 'Готовий до ранкових завдань?',
      'afternoonSubtitle': 'Як проходить день?',
      'eveningSubtitle': 'Час завершити день!',
      'nightSubtitle': 'Про що думаєш?',
      'notesMorningSubtitle': 'Запиши ранкові думки',
      'notesAfternoonSubtitle': 'Готовий записати ідеї?',
      'notesEveningSubtitle': 'Вечірні думки?',
      'notesNightSubtitle': 'Про що думаєш?',
    },
  ];

  /// Get greeting text based on hour and language index
  static String getGreeting({
    required int hour,
    required int languageIndex,
    required String userName,
  }) {
    final safeIndex = languageIndex.clamp(0, _greetings.length - 1);
    final greetingMap = _greetings[safeIndex];

    String greetingKey;
    if (hour < 12) {
      greetingKey = 'morning';
    } else if (hour < 17) {
      greetingKey = 'afternoon';
    } else if (hour < 21) {
      greetingKey = 'evening';
    } else {
      greetingKey = 'night';
    }

    // Check if user has set a name
    final hasUserName =
        userName.isNotEmpty &&
        userName != '_SKIP_NAME_' &&
        userName != '_CLEARED_NAME_';

    // Return greeting with name if set, otherwise just the greeting
    if (hasUserName) {
      return '${greetingMap[greetingKey]}, $userName';
    } else {
      return greetingMap[greetingKey] as String;
    }
  }

  /// Get subtitle for tasks screen based on hour and language index
  static String getTasksSubtitle({
    required int hour,
    required int languageIndex,
  }) {
    final safeIndex = languageIndex.clamp(0, _greetings.length - 1);
    final greetingMap = _greetings[safeIndex];

    if (hour < 12) {
      return greetingMap['morningSubtitle'] as String;
    } else if (hour < 17) {
      return greetingMap['afternoonSubtitle'] as String;
    } else {
      return greetingMap['eveningSubtitle'] as String;
    }
  }

  /// Get subtitle for notes screen based on hour and language index
  static String getNotesSubtitle({
    required int hour,
    required int languageIndex,
  }) {
    final safeIndex = languageIndex.clamp(0, _greetings.length - 1);
    final greetingMap = _greetings[safeIndex];

    if (hour < 12) {
      return greetingMap['notesMorningSubtitle'] as String;
    } else if (hour < 17) {
      return greetingMap['notesAfternoonSubtitle'] as String;
    } else if (hour < 21) {
      return greetingMap['notesEveningSubtitle'] as String;
    } else {
      return greetingMap['notesNightSubtitle'] as String;
    }
  }
}
