import 'package:flutter/material.dart';

class AppStrings {
  final Locale locale;
  const AppStrings(this.locale);

  static AppStrings of(BuildContext context) => AppStrings(Localizations.localeOf(context));
  String get _lc => locale.languageCode;

  String get navHome => _t({'en':'Home','ru':'Главная','kk':'Басты бет'});
  String get navStore => _t({'en':'Store','ru':'Магазин','kk':'Дүкен'});
  String get navSettings => _t({'en':'Settings','ru':'Настройки','kk':'Баптаулар'});

  String get settingsTitle => _t({'en':'Settings','ru':'Настройки','kk':'Баптаулар'});
  String get name => _t({'en':'Name','ru':'Имя','kk':'Есім'});
  String get lastName => _t({'en':'Surname','ru':'Фамилия','kk':'Тегі'});
  String get age => _t({'en':'Age','ru':'Возраст','kk':'Жас'});
  String get weight => _t({'en':'Weight (kg)','ru':'Вес (кг)','kk':'Салмақ (кг)'});
  String get height => _t({'en':'Height (cm)','ru':'Рост (см)','kk':'Биіктік (см)'});
  String get gender => _t({'en':'Gender','ru':'Пол','kk':'Жыныс'});
  String get male => _t({'en':'Male','ru':'Мужской','kk':'Ер'});
  String get female => _t({'en':'Female','ru':'Женский','kk':'Әйел'});
  String get goal => _t({'en':'Goal','ru':'Цель','kk':'Мақсат'});
  String get goalBurnFat => _t({'en':'Burn fat','ru':'Сжечь жир','kk':'Май жағу'});
  String get goalBuildMuscle => _t({'en':'Build muscle','ru':'Накачать мышцы','kk':'Бұлшықет жинау'});
  String get goalMaintain => _t({'en':'Maintain shape','ru':'Поддерживать форму','kk':'Форманы сақтау'});
  String get saveProfile => _t({'en':'Save profile','ru':'Сохранить профиль','kk':'Профильді сақтау'});

  String get appearance => _t({'en':'Appearance','ru':'Оформление','kk':'Көрініс'});
  String get theme => _t({'en':'Theme','ru':'Тема','kk':'Тақырып'});
  String get system => _t({'en':'System','ru':'Системная','kk':'Жүйелік'});
  String get light => _t({'en':'Light','ru':'Светлая','kk':'Жарық'});
  String get dark => _t({'en':'Dark','ru':'Тёмная','kk':'Қараңғы'});
  String get accentColor => _t({'en':'Accent color','ru':'Акцентный цвет','kk':'Акцент түсі'});
  String get language => _t({'en':'Language','ru':'Язык','kk':'Тіл'});
  String get allApps => _t({'en':'All apps','ru':'Все приложения','kk':'Барлық қосымшалар'});
  String get blockedApps => _t({'en':'Blocked','ru':'Заблокированные','kk':'Блокталған'});
  String get blockingSetup => _t({'en':'Blocking setup','ru':'Настройка блокировки','kk':'Блоктауды баптау'});
  String get appsNotFound => _t({'en':'No apps found','ru':'Приложения не найдены','kk':'Қосымшалар табылмады'});
  String get emptyBlockedTitle => _t({'en':'Blocked apps will appear here.\n\nGo to "All apps" to select apps to block.',
    'ru':'Здесь будут отображаться заблокированные приложения.\n\nПерейдите на вкладку "Все приложения", чтобы выбрать приложения для блокировки.',
    'kk':'Мұнда блокталған қолданбалар көрсетіледі.\n\n"Барлық қосымшалар" бөліміне өтіп, блоктайтындарды таңдаңыз.'});
  String buyMinutes(int minutes, int cost) => _t({'en':'Purchased $minutes min for $cost 💎', 'ru':'Куплено $minutes мин за $cost 💎', 'kk':'$minutes мин $cost 💎-ға сатып алынды'});
  String minutesPriceLabel(int minutes, int cost) => _t({
    'en': '$minutes min\n$cost 💎',
    'ru': '$minutes мин\n$cost 💎',
    'kk': '$minutes мин\n$cost 💎',
  });

  // Exercises
  String get squats => _t({'en':'Squats','ru':'Приседания','kk':'Отырғыштар'});
  String get pushups => _t({'en':'Push-ups','ru':'Отжимания','kk':'Итерілу'});
  String get crunches => _t({'en':'Crunches','ru':'Пресс','kk':'Пресс'});
  String goalReps(int reps) => _t({'en':'Goal: $reps reps','ru':'Цель: $reps повторений','kk':'Мақсат: $reps рет'});

  // Onboarding
  String get welcomeTitle => _t({'en':'Welcome to FitAI!','ru':'Добро пожаловать в FitAI!','kk':'FitAI-ға қош келдіңіз!'});
  String get welcomeDesc => _t({'en':'Your personal AI coach. Works offline.','ru':'Ваш персональный AI‑тренер. Работает оффлайн.','kk':'Жеке AI-жаттықтырушы. Офлайн жұмыс істейді.'});
  String get start => _t({'en':'Start','ru':'Начать','kk':'Бастау'});
  String get next => _t({'en':'Next','ru':'Далее','kk':'Келесі'});
  String get finish => _t({'en':'Finish','ru':'Готово','kk':'Дайын'});
  String get chooseLanguage => _t({'en':'Choose language','ru':'Выберите язык','kk':'Тілді таңдаңыз'});
  String get chooseTheme => _t({'en':'Choose theme and color','ru':'Выберите тему и цвет','kk':'Тақырып пен түсті таңдаңыз'});
  String get addPhoto => _t({'en':'Add a profile photo','ru':'Добавьте фото профиля','kk':'Профиль фотосын қосыңыз'});
  String get enterName => _t({'en':'Enter your name and surname','ru':'Имя и фамилия','kk':'Есім мен тегі'});
  String get bodyParams => _t({'en':'Your body parameters','ru':'Параметры тела','kk':'Дене параметрлері'});
  String get selectGender => _t({'en':'Select gender','ru':'Выберите пол','kk':'Жынысты таңдаңыз'});
  String get selectGoal => _t({'en':'Your goal','ru':'Ваша цель','kk':'Мақсатыңыз'});

  // Chart labels
  String get axisDays => _t({'en':'Days','ru':'Дни','kk':'Күндер'});
  String get axisReps => _t({'en':'Reps','ru':'Повторения','kk':'Қайталаулар'});
  String weekdayShort(int weekday) => _t({
    'en': ['','Mon','Tue','Wed','Thu','Fri','Sat','Sun'][weekday],
    'ru': ['','Пн','Вт','Ср','Чт','Пт','Сб','Вс'][weekday],
    'kk': ['','Дс','Сс','Ср','Бс','Жм','Сб','Жс'][weekday],
  });

  // Camera / full body instructions
  String get fullBodyRequired => _t({
    'en':'Make sure your full body is visible',
    'ru':'Убедитесь, что ваше тело полностью видно',
    'kk':'Денеңіз толық көрінетініне көз жеткізіңіз',
  });

  // Results screen
  String get resultGreat => _t({'en':'Great!','ru':'Отлично!','kk':'Өте жақсы!'});
  String repsDone(int reps) => _t({'en':'Completed: $reps reps','ru':'Выполнено: $reps повторений','kk':'Орындалды: $reps рет'});
  String avgQuality(double q) => _t({'en':'Average quality: ${q.toStringAsFixed(0)}%','ru':'Среднее качество: ${q.toStringAsFixed(0)}%','kk':'Орташа сапа: ${q.toStringAsFixed(0)}%'});
  String get earnedDiamonds => _t({'en':'+10 💎 earned!','ru':'+10 💎 заработано!','kk':'+10 💎 алынды!'});
  String get done => _t({'en':'Done','ru':'Готово','kk':'Дайын'});

  // Store / blocker tab
  String get unlocked => _t({'en':'Unlocked','ru':'Разблокировано','kk':'Бұғат ашылды'});
  String get blocked => _t({'en':'Blocked','ru':'Заблокировано','kk':'Бұғатталған'});
  String get timeLeft => _t({'en':'Time left','ru':'Осталось','kk':'Қалды'});
  String get buyUnlockMinutes => _t({'en':'Buy unlock minutes:','ru':'Купить минуты разблокировки:','kk':'Бұғат ашу минуттарын сатып алу:'});
  String get stepBackHint => _t({
    'en':'Step back a little so we can see head and ankles',
    'ru':'Отойдите чуть дальше, чтобы были видны голова и лодыжки',
    'kk':'Бас пен асықты көру үшін сәл шегініңіз',
  });

  String _t(Map<String,String> m) => m[_lc] ?? m['en']!;
}


