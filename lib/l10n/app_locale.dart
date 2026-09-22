enum AppLocale {
  ru,
  en;

  bool get isRu => this == AppLocale.ru;
}

class AppStrings {
  String get joinCoach =>
      locale.isRu ? 'Присоединиться к тренеру' : 'Join a coach';
  String get findCoach => locale.isRu ? 'Найти тренера' : 'Find coach';
  String get confirmJoinCoach =>
      locale.isRu ? 'Подтвердить присоединение' : 'Confirm joining';
  String get coachJoined =>
      locale.isRu ? 'Вы присоединились к тренеру' : 'You have joined the coach';
  String get clubNotSpecified =>
      locale.isRu ? 'Клуб не указан' : 'Club not specified';
  String get studentProfileSetup =>
      locale.isRu ? 'Анкета ученика' : 'Student profile';
  String get finishRegistration =>
      locale.isRu ? 'Завершить регистрацию' : 'Complete registration';
  String get invalidWeight => locale.isRu
      ? 'Укажите вес от 1 до 300 кг'
      : 'Enter a weight from 1 to 300 kg';
  const AppStrings(this.locale);

  final AppLocale locale;

  String spectatorStage(String title) => switch (title) {
    'Финал' || 'Final' => locale.isRu ? 'Финал' : 'Final',
    'Предварительный круг' || 'Preliminary stage' => preliminaryRound,
    '3-е место' || 'Third place' => thirdPlace,
    _ => title,
  };
  String get team => locale.isRu ? 'Команда' : 'Team';
  String rankValue(String? value) {
    if (value == null || value.trim().isEmpty) return '—';
    final rank = value.trim();
    if (RegExp(r'^\d+$').hasMatch(rank)) {
      return '$rank ${locale.isRu ? 'кю' : 'kyu'}';
    }
    return rank.replaceAllMapped(
      RegExp(r'кю|kyu|дан|dan', caseSensitive: false),
      (match) {
        final dan = ['дан', 'dan'].contains(match.group(0)!.toLowerCase());
        return dan
            ? (locale.isRu ? 'дан' : 'dan')
            : (locale.isRu ? 'кю' : 'kyu');
      },
    );
  }

  String get cm => locale.isRu ? 'см' : 'cm';
  String get referee => locale.isRu ? 'Р' : 'R';
  String get kg => locale.isRu ? 'кг' : 'kg';
  String get sourceLists =>
      locale.isRu ? 'Списки участников' : 'Participant lists';
  String get quickFights => locale.isRu ? 'Быстрые данные' : 'Quick data';
  String get listsExcel => locale.isRu ? 'Списки Excel' : 'Lists Excel';
  String get listsPdf => locale.isRu ? 'Списки PDF' : 'Lists PDF';
  String get notGenerated => locale.isRu ? 'Не сгенерировано' : 'Not generated';
  String get currentFight => locale.isRu ? 'Текущий' : 'Current';
  String get nextFight => locale.isRu ? 'Следующий' : 'Next';
  String get wazari => locale.isRu ? 'Вазари' : 'Wazari';
  String get ippon => locale.isRu ? 'Иппон' : 'Ippon';
  String get absence => locale.isRu ? 'Неявка' : 'Absent';
  String fightPathStatus(String value) => switch (value) {
    'won' => locale.isRu ? 'Победа' : 'Won',
    'lost' => locale.isRu ? 'Поражение' : 'Lost',
    'absent' => absence,
    'possible' => locale.isRu ? 'Возможный' : 'Possible',
    'scored' => locale.isRu ? 'Оценено' : 'Scored',
    _ => locale.isRu ? 'Ожидает' : 'Upcoming',
  };

  String get invalidServerResponse =>
      locale.isRu ? 'Некорректный ответ сервера' : 'Invalid server response';
  String get requestFailed => locale.isRu
      ? 'Не удалось выполнить запрос. Повторите попытку.'
      : 'Request failed. Please try again.';
  String get aboutLoadFailed => locale.isRu
      ? 'Не удалось загрузить информацию о проекте'
      : 'Unable to load project information';
  String get appTitle => 'KumiteRating';
  String get loginTitle => locale.isRu ? 'Вход' : 'Sign in';
  String get loginSubtitle => locale.isRu
      ? 'Войдите в свой аккаунт, чтобы продолжить'
      : 'Sign in to your account to continue';
  String get email => 'Email';
  String get password => locale.isRu ? 'Пароль' : 'Password';
  String get rememberMe => locale.isRu ? 'Запомнить меня' : 'Remember me';
  String get forgotPassword =>
      locale.isRu ? 'Забыли пароль?' : 'Forgot password?';
  String get signIn => locale.isRu ? 'Войти' : 'Sign in';
  String get noAccount => locale.isRu ? 'Нет аккаунта?' : 'No account?';
  String get register => locale.isRu ? 'Зарегистрироваться' : 'Register';
  String get studentRegistration =>
      locale.isRu ? 'Регистрация ученика' : 'Student registration';
  String get coachRegistration =>
      locale.isRu ? 'Регистрация тренера' : 'Coach registration';
  String get existingAccount =>
      locale.isRu ? 'У меня уже есть аккаунт' : 'I already have an account';
  String get organizationCode =>
      locale.isRu ? 'Код организации' : 'Organization code';
  String get confirmPassword =>
      locale.isRu ? 'Повторите пароль' : 'Confirm password';
  String get requiredField =>
      locale.isRu ? 'Заполните поле' : 'This field is required';
  String get passwordMismatch =>
      locale.isRu ? 'Пароли не совпадают' : 'Passwords do not match';
  String get registrationPasswordLength =>
      locale.isRu ? 'Минимум 8 символов' : 'At least 8 characters';
  String get registrationCodeLength =>
      locale.isRu ? 'Введите 6 цифр из письма' : 'Enter the 6-digit email code';
  String get registrationFailed => locale.isRu
      ? 'Не удалось завершить регистрацию. Повторите запрос.'
      : 'Registration could not be completed. Please retry.';
  String get registrationComplete => locale.isRu
      ? 'Регистрация завершена. Войдите в свой аккаунт.'
      : 'Registration complete. Sign in to your account.';
  String get backToRegistration => locale.isRu
      ? 'Назад к данным регистрации'
      : 'Back to registration details';
  String registrationCodeSent(String email) => locale.isRu
      ? 'Код подтверждения отправлен на $email. Срок действия — 10 минут.'
      : 'A verification code was sent to $email. It is valid for 10 minutes.';
  String get showPassword => locale.isRu ? 'Показать пароль' : 'Show password';
  String get hidePassword => locale.isRu ? 'Скрыть пароль' : 'Hide password';
  String get joinExam => locale.isRu ? 'Записаться' : 'Join';
  String get joinExamConfirm =>
      locale.isRu ? 'Записаться на экзамен?' : 'Join this examination?';
  String get joinTournamentConfirm =>
      locale.isRu ? 'Записаться на турнир?' : 'Join this tournament?';
  String get studentRole => locale.isRu ? 'Ученик' : 'Student';
  String get restoreAccount =>
      locale.isRu ? 'Восстановить аккаунт' : 'Restore account';
  String get restoreEmailSent => locale.isRu
      ? 'Если аккаунт доступен для восстановления, код отправлен на email.'
      : 'If the account can be restored, a code has been sent to your email.';
  String get verificationCode => locale.isRu ? 'Код из письма' : 'Email code';
  String get repeatPassword =>
      locale.isRu ? 'Повторите пароль' : 'Repeat password';
  String get sendCode => locale.isRu ? 'Отправить код' : 'Send code';
  String get newEducationWork => locale.isRu ? 'Добавить работу' : 'Add work';
  String get exportNotReady => locale.isRu
      ? 'Не удалось подготовить файл. Повторите выгрузку.'
      : 'The file could not be prepared. Retry the export.';
  String get acceptOffer => locale.isRu
      ? 'Принимаю условия оферты и подтверждаю оплату'
      : 'I accept the offer and confirm payment';
  String get emailRequired => locale.isRu ? 'Введите email' : 'Enter email';
  String get passwordRequired =>
      locale.isRu ? 'Введите пароль' : 'Enter password';
  String get invalidEmail =>
      locale.isRu ? 'Некорректный email' : 'Invalid email';
  String get stubTitle => locale.isRu ? 'Панель тренера' : 'Coach panel';
  String get stubBody => locale.isRu
      ? 'Здесь будет первая рабочая страница тренера.'
      : 'The first coach workspace screen will be here.';
  String get logoutQuestion =>
      locale.isRu ? 'Выйти из аккаунта?' : 'Log out of your account?';
  String get logoutFailed => locale.isRu
      ? 'Не удалось завершить сессию на сервере. Проверьте соединение и повторите.'
      : 'Could not revoke the session. Check your connection and try again.';
  String get sessionCheckFailed => locale.isRu
      ? 'Не удалось проверить сессию. Проверьте соединение и повторите.'
      : 'Could not verify the session. Check your connection and try again.';
  String get browserOpenFailed => locale.isRu
      ? 'Не удалось открыть браузер.'
      : 'Could not open the browser.';
  String get previousPage =>
      locale.isRu ? 'Предыдущая страница' : 'Previous page';
  String get nextPage => locale.isRu ? 'Следующая страница' : 'Next page';
  String get accountDeleteFailed => locale.isRu
      ? 'Не удалось удалить аккаунт. Повторите попытку.'
      : 'Could not delete the account. Try again.';
  String get deleteAccount =>
      locale.isRu ? 'Удалить аккаунт' : 'Delete account';
  String get deleteAccountWarning => locale.isRu
      ? 'Доступ к аккаунту будет закрыт на всех устройствах. Ученики и результаты соревнований сохранятся. Введите пароль для подтверждения.'
      : 'Account access will be closed on all devices. Students and competition results will be retained. Enter your password to confirm.';
  String get dateFormatHint => locale.isRu ? 'дд.мм.гггг' : 'dd.mm.yyyy';
  String get agreements => locale.isRu ? 'Соглашения' : 'Agreements';
  String get acceptAgreement =>
      locale.isRu ? 'Я принимаю условия документа' : 'I accept this document';
  String get agreementAccepted => locale.isRu ? 'Принято' : 'Accepted';
  String get agreementRequired =>
      locale.isRu ? 'Требуется согласие' : 'Consent required';
  String get agreementsUnavailable => locale.isRu
      ? 'Не удалось загрузить соглашения.'
      : 'Could not load agreements.';
  String get continueLabel => locale.isRu ? 'Продолжить' : 'Continue';
  String get logout => locale.isRu ? 'Выйти' : 'Log out';
  String get send => locale.isRu ? 'Отправить' : 'Send';
  String get feedSettings => locale.isRu ? 'Настройки ленты' : 'Feed settings';
  String get feedCity => locale.isRu ? 'Город' : 'City';
  String get feedAllOrganizations =>
      locale.isRu ? 'Все организации' : 'All organizations';
  String get feedChooseCity => locale.isRu ? 'Выберите город' : 'Select a city';
  String get feedNoPosts =>
      locale.isRu ? 'Публикаций пока нет' : 'No posts yet';
  String get feedReplies => locale.isRu ? 'Ответы' : 'Replies';
  String get feedRemoveQuestion =>
      locale.isRu ? 'Удалить запись?' : 'Delete this entry?';
  String get feedMediaError =>
      locale.isRu ? 'Не удалось открыть вложение' : 'Could not open attachment';
  String feedReaction(String type) => switch (type) {
    'love' => locale.isRu ? 'Нравится' : 'Love',
    'like' => locale.isRu ? 'Одобряю' : 'Like',
    'funny' => locale.isRu ? 'Смешно' : 'Funny',
    'fire' => locale.isRu ? 'Огонь' : 'Fire',
    'sad' => locale.isRu ? 'Грустно' : 'Sad',
    _ => type,
  };
  String get feed => locale.isRu ? 'Лента' : 'Feed';
  String get participantsFeed =>
      locale.isRu ? 'Лента участников' : 'Participants feed';
  String get all => locale.isRu ? 'Все' : 'All';
  String get myStudents => locale.isRu ? 'Мои ученики' : 'My students';
  String get coaches => locale.isRu ? 'Тренеры' : 'Coaches';
  String get participants => locale.isRu ? 'Участники' : 'Participants';
  String get organization => locale.isRu ? 'Организация' : 'Organization';
  String get shareNews => locale.isRu
      ? 'Поделитесь новостью с участниками...'
      : 'Share news with participants...';
  String get photo => locale.isRu ? 'Фото' : 'Photo';
  String get video => locale.isRu ? 'Видео' : 'Video';
  String get announcement => locale.isRu ? 'Объявление' : 'Announcement';
  String get publish => locale.isRu ? 'Опубликовать' : 'Publish';
  String get edit => locale.isRu ? 'Редактировать' : 'Edit';
  String get delete => locale.isRu ? 'Удалить' : 'Delete';
  String get save => locale.isRu ? 'Сохранить' : 'Save';
  String get editStudent =>
      locale.isRu ? 'Редактирование ученика' : 'Edit student';
  String get editProfile =>
      locale.isRu ? 'Редактировать профиль' : 'Edit profile';
  String get firstName => locale.isRu ? 'Имя' : 'First name';
  String get lastName => locale.isRu ? 'Фамилия' : 'Last name';
  String get patronymic => locale.isRu ? 'Отчество' : 'Patronymic';
  String get cancel => locale.isRu ? 'Отмена' : 'Cancel';
  String get apply => locale.isRu ? 'Применить' : 'Apply';
  String get reset => locale.isRu ? 'Сбросить' : 'Reset';
  String get checkFields => locale.isRu ? 'Проверьте поля' : 'Check fields';
  String get comment => locale.isRu ? 'Комментарий' : 'Comment';
  String get comments => locale.isRu ? 'Комментарии' : 'Comments';
  String get writeComment =>
      locale.isRu ? 'Написать комментарий...' : 'Write a comment...';
  String get reply => locale.isRu ? 'Ответить' : 'Reply';
  String get share => locale.isRu ? 'Поделиться' : 'Share';
  String get home => locale.isRu ? 'Главная' : 'Home';
  String get tournaments => locale.isRu ? 'Турниры' : 'Tournaments';
  String get championships => locale.isRu ? 'Чемпионаты' : 'Championships';
  String get students => locale.isRu ? 'Ученики' : 'Students';
  String get studentProfile =>
      locale.isRu ? 'Профиль ученика' : 'Student profile';
  String get waiting => locale.isRu ? 'Ожидают' : 'Waiting';
  String get age => locale.isRu ? 'Возраст' : 'Age';
  String get belt => locale.isRu ? 'Пояс' : 'Belt';
  String get gender => locale.isRu ? 'Пол' : 'Gender';
  String get club => locale.isRu ? 'Клуб' : 'Club';
  String get coach => locale.isRu ? 'Тренер' : 'Coach';
  String get birthDate => locale.isRu ? 'Дата рождения' : 'Birth date';
  String get weight => locale.isRu ? 'Вес' : 'Weight';
  String get height => locale.isRu ? 'Рост' : 'Height';
  String get kyuDan => locale.isRu ? 'Кю / Дан' : 'Kyu / Dan';
  String get trainingCity => locale.isRu ? 'Город тренировок' : 'Training city';
  String get brandNumber => locale.isRu ? 'Номер марки' : 'Stamp number';
  String get ikoNumber => locale.isRu ? 'Номер ИКО' : 'IKO number';
  String get certificateNumber =>
      locale.isRu ? 'Номер сертификата' : 'Certificate number';
  String get lastExamDate =>
      locale.isRu ? 'Дата последнего экзамена' : 'Last exam date';
  String get lastExamCity => locale.isRu ? 'Город экзамена' : 'Exam city';
  String get lastReceiving =>
      locale.isRu ? 'БЧ принимавший экзамен' : 'Examiner';
  String get documentUploads =>
      locale.isRu ? 'Файлы документов' : 'Document files';
  String get chooseFile => locale.isRu ? 'Выбрать файл' : 'Choose file';
  String get fileSelected => locale.isRu ? 'Файл выбран' : 'File selected';
  String get activeTournament =>
      locale.isRu ? 'активный турнир' : 'active tournament';
  String get activeTournaments =>
      locale.isRu ? 'активных турнира' : 'active tournaments';
  String get onTournament => locale.isRu ? 'На турнире' : 'In tournament';
  String get newStatus => locale.isRu ? 'Новый' : 'New';
  String get documentsOk =>
      locale.isRu ? 'Документы в порядке' : 'Documents are OK';
  String get medicalUntil =>
      locale.isRu ? 'Медсправка до' : 'Medical certificate until';
  String get includedInDocumentCheck => locale.isRu
      ? 'Участие в проверке документов'
      : 'Included in document check';
  String get search => locale.isRu ? 'Поиск...' : 'Search...';
  String get noStudents =>
      locale.isRu ? 'Ученики не найдены' : 'No students found';
  String get position => locale.isRu ? 'позиция' : 'position';
  String get gold => locale.isRu ? 'Золото' : 'Gold';
  String get silver => locale.isRu ? 'Серебро' : 'Silver';
  String get bronze => locale.isRu ? 'Бронза' : 'Bronze';
  String get record => locale.isRu ? 'Рекорд' : 'Record';
  String get wins => locale.isRu ? 'Победы' : 'Wins';
  String get losses => locale.isRu ? 'Поражения' : 'Losses';
  String get totalFights => locale.isRu ? 'Всего боёв' : 'Total fights';
  String get latestResults =>
      locale.isRu ? 'Последние результаты' : 'Latest results';
  String get confirmed => locale.isRu ? 'Подтверждено' : 'Confirmed';
  String get notConfirmed => locale.isRu ? 'Не подтверждено' : 'Not confirmed';
  String get insurance => locale.isRu ? 'Страховка' : 'Insurance';
  String get ikoCard => locale.isRu ? 'Карта ИКО' : 'IKO card';
  String get certificate => locale.isRu ? 'Сертификат' : 'Certificate';
  String get passport => locale.isRu ? 'Будо паспорт' : 'Budo passport';
  String get brand => locale.isRu ? 'Марка' : 'Stamp';
  String get yellowBelt => locale.isRu ? 'Жёлтый пояс' : 'Yellow belt';
  String get whiteBelt => locale.isRu ? 'Белый пояс' : 'White belt';
  String get orangeBelt => locale.isRu ? 'Оранжевый пояс' : 'Orange belt';
  String get blueBelt => locale.isRu ? 'Синий пояс' : 'Blue belt';
  String get greenBelt => locale.isRu ? 'Зелёный пояс' : 'Green belt';
  String get brownBelt => locale.isRu ? 'Коричневый пояс' : 'Brown belt';
  String get blackBelt => locale.isRu ? 'Чёрный пояс' : 'Black belt';
  String get beltNotSet => locale.isRu ? 'Пояс не указан' : 'Belt not set';
  String get profile => locale.isRu ? 'Профиль' : 'Profile';
  String get settings => locale.isRu ? 'Настройки' : 'Settings';
  String get profileLoadFailed =>
      locale.isRu ? 'Не удалось загрузить профиль' : 'Could not load profile';
  String get more => locale.isRu ? 'Ещё' : 'More';
  String get rating => locale.isRu ? 'Рейтинг' : 'Rating';
  String get kumite => locale.isRu ? 'Кумитэ' : 'Kumite';
  String get kata => locale.isRu ? 'Ката' : 'Kata';
  String get year => '2026';
  String get allAges => locale.isRu ? 'Все возраста' : 'All ages';
  String get from14 => locale.isRu ? '14+' : '14+';
  String get allBelts => locale.isRu ? 'Все пояса' : 'All belts';
  String get allWeights => locale.isRu ? 'Все веса' : 'All weights';
  String get bothGenders => locale.isRu ? 'М и Ж' : 'M and F';
  String get allCategories => locale.isRu ? 'Все категории' : 'All categories';
  String get yearLabel => locale.isRu ? 'Год' : 'Year';
  String get ratingType => locale.isRu ? 'Тип рейтинга' : 'Rating type';
  String get weightCategory =>
      locale.isRu ? 'Весовая категория' : 'Weight category';
  String get male => locale.isRu ? 'Мальчик' : 'Boy';
  String get female => locale.isRu ? 'Девочка' : 'Girl';
  String get maleShort => locale.isRu ? 'М' : 'M';
  String get femaleShort => locale.isRu ? 'Ж' : 'F';
  String get allTournaments => locale.isRu ? 'Все турниры' : 'All tournaments';
  String get noTournaments =>
      locale.isRu ? 'Турниры не найдены' : 'No tournaments found';
  String get myTournaments => locale.isRu ? 'Мои турниры' : 'My tournaments';
  String get notMyTournaments =>
      locale.isRu ? 'Не мои турниры' : 'Other tournaments';
  String get active => locale.isRu ? 'Активные' : 'Active';
  String get completed => locale.isRu ? 'Завершённые' : 'Completed';
  String get completedShort => locale.isRu ? 'Заверш.' : 'Completed';
  String get withActiveTournament =>
      locale.isRu ? 'С активными турнирами' : 'With active tournaments';
  String get withoutActiveTournament =>
      locale.isRu ? 'Без активных турниров' : 'Without active tournaments';
  String get activeShort => locale.isRu ? 'Активные' : 'Active';
  String get noActiveShort => locale.isRu ? 'Без актив.' : 'No active';
  String get region => locale.isRu ? 'Регион' : 'Region';
  String get topCoachesRating =>
      locale.isRu ? 'ТОП 15 РЕЙТИНГА ПО ТРЕНЕРАМ' : 'TOP 15 COACH RATING';
  String get allCategoriesCount =>
      locale.isRu ? 'В зачёте всех категорий' : 'Across all categories';
  String get showFullCoachRating => locale.isRu
      ? 'Смотреть полный рейтинг тренеров'
      : 'Open full coach rating';
  String get points => locale.isRu ? 'баллов' : 'points';
  String get pointSingle => locale.isRu ? 'балл' : 'point';
  String get filter => locale.isRu ? 'Фильтр' : 'Filter';
  String get emptyPost => locale.isRu
      ? 'Добавьте текст, фото или видео'
      : 'Add text, photo or video';
  String get attachPhotoOrVideo =>
      locale.isRu ? 'Прикрепить фото или видео' : 'Attach photo or video';
  String get about => locale.isRu ? 'О нас' : 'About';
  String get aboutHeadline => appTitle;
  String get aboutLead => locale.isRu
      ? 'Платформа для тренеров, спортсменов и организаций'
      : 'A platform for coaches, athletes, and organizations';
  String get athletesCount => locale.isRu ? 'Спортсменов' : 'Athletes';
  String get clubsCount => locale.isRu ? 'Клубов' : 'Clubs';
  String get tournamentsCount => locale.isRu ? 'Турниров' : 'Tournaments';
  String get aboutProject => locale.isRu ? 'О проекте' : 'About the project';
  String get aboutProjectText => locale.isRu
      ? 'Karaterating — это информационная и организационная платформа, посвящённая развитию каратэ в России и странах СНГ.\n\nМы объединяем спортсменов, инструкторов и организации, чтобы создавать удобную среду для обучения, участия в соревнованиях, ведения личных спортивных рейтингов и общения.\n\nНаша цель — сделать каратэ технологичным. Проект реализуется при поддержке энтузиастов и профессионалов в сфере боевых искусств, с акцентом на развитие спорта среди молодежи.'
      : 'Karaterating is an information and organization platform focused on developing karate in Russia and the CIS.\n\nWe bring together athletes, instructors, and organizations to create a convenient environment for learning, competitions, personal sports rankings, and communication.\n\nOur goal is to make karate more technological. The project is supported by martial arts enthusiasts and professionals, with a focus on youth sport development.';
  String get learning => locale.isRu ? 'Обучение' : 'Learning';
  String get competitionParticipation =>
      locale.isRu ? 'Участие в соревнованиях' : 'Competitions';
  String get personalSportsRatings =>
      locale.isRu ? 'Личные спортивные рейтинги' : 'Personal rankings';
  String get communication => locale.isRu ? 'Общение' : 'Communication';
  String get companyInfo =>
      locale.isRu ? 'Информация о компании' : 'Company information';
  String get companyName =>
      locale.isRu ? 'Наименование организации' : 'Company name';
  String get companyNameValue =>
      locale.isRu ? 'ПНПД Ткодян Е.В.' : 'PNPD Tkodyan E.V.';
  String get taxId => locale.isRu ? 'ИНН' : 'Tax ID';
  String get companyAddress => locale.isRu ? 'Адрес' : 'Address';
  String get companyAddressValue => locale.isRu
      ? 'г. Ростов-на-Дону, пр-кт Соколова д. 68/118в, кв. 209'
      : 'Rostov-on-Don, Sokolova Ave. 68/118v, apt. 209';
  String get bankDetails =>
      locale.isRu ? 'Банковские реквизиты' : 'Bank details';
  String get bank => locale.isRu ? 'Банк' : 'Bank';
  String get bankValue => locale.isRu
      ? 'Филиал № 2351 Банка ВТБ (публичное акционерное общество) в г. Краснодаре'
      : 'Branch No. 2351 of VTB Bank (Public Joint-Stock Company), Krasnodar';
  String get bik => locale.isRu ? 'БИК' : 'BIC';
  String get account => locale.isRu ? 'Л/с' : 'Account';
  String get correspondentAccount =>
      locale.isRu ? 'К/с' : 'Correspondent account';
  String get workTime => locale.isRu ? 'Время работы' : 'Working hours';
  String get workTimeValue => locale.isRu
      ? 'Пн-Пт с 10:00 до 18:00 (МСК)'
      : 'Mon-Fri, 10:00-18:00 (MSK)';
  String get ourMission => locale.isRu ? 'Наша миссия' : 'Our mission';
  String get sportGrowth => locale.isRu ? 'Развитие спорта' : 'Sport growth';
  String get sportGrowthText => locale.isRu
      ? 'Создаём инструменты для роста и мотивации спортсменов.'
      : 'We create tools for athlete growth and motivation.';
  String get transparentRatings =>
      locale.isRu ? 'Прозрачные рейтинги' : 'Transparent rankings';
  String get transparentRatingsText => locale.isRu
      ? 'Объективные результаты и честное ранжирование для всех.'
      : 'Objective results and fair ranking for everyone.';
  String get convenientInteraction =>
      locale.isRu ? 'Удобное взаимодействие' : 'Convenient interaction';
  String get convenientInteractionText => locale.isRu
      ? 'Связываем тренеров, спортсменов и клубы в единой экосистеме.'
      : 'We connect coaches, athletes, and clubs in one ecosystem.';
  String get availableInApp =>
      locale.isRu ? 'Что доступно в приложении' : 'Available in the app';
  String get exams => locale.isRu ? 'Экзамены' : 'Exams';
  String get exam => locale.isRu ? 'Экзамен' : 'Exam';
  String get date => locale.isRu ? 'Дата' : 'Date';
  String get dateFrom => locale.isRu ? 'Дата от' : 'Date from';
  String get dateTo => locale.isRu ? 'Дата до' : 'Date to';
  String get place => locale.isRu ? 'Место' : 'Place';
  String get receiving => locale.isRu ? 'Принимающий БЧ' : 'Examiner';
  String get examName => locale.isRu ? 'Название' : 'Name';
  String get examPlace => locale.isRu ? 'Место проведения' : 'Exam location';
  String get shown => locale.isRu ? 'Показано' : 'Shown';
  String get of => locale.isRu ? 'из' : 'of';
  String get attachStudent =>
      locale.isRu ? 'Прикрепить ученика' : 'Attach student';
  String get detach => locale.isRu ? 'Открепить' : 'Detach';
  String get excel => locale.isRu ? 'Excel' : 'Excel';
  String get attach => locale.isRu ? 'Прикрепить' : 'Attach';
  String get selected => locale.isRu ? 'Выбрано' : 'Selected';
  String get noExams => locale.isRu ? 'Экзамены не найдены' : 'No exams found';
  String get noParticipants =>
      locale.isRu ? 'Участники не найдены' : 'No participants found';
  String get tables => locale.isRu ? 'Таблицы' : 'Tables';
  String get pools => locale.isRu ? 'Пули' : 'Pools';
  String get documentsOkShort => locale.isRu ? 'Документы OK' : 'Documents OK';
  String get videoOk => locale.isRu ? 'Видео OK' : 'Video OK';
  String get noVideo => locale.isRu ? 'Нет видео' : 'No video';
  String get openProfile => locale.isRu ? 'Профиль' : 'Profile';
  String get searchParticipant =>
      locale.isRu ? 'Поиск участника' : 'Search participant';
  String get searchCoach => locale.isRu ? 'Поиск тренера' : 'Search coach';
  String get searchPool => locale.isRu ? 'Поиск пули' : 'Search pool';
  String get downloadLists => locale.isRu ? 'Скачать списки' : 'Download lists';
  String get commissionDate =>
      locale.isRu ? 'Дата комиссии' : 'Commission date';
  String get finishDate => locale.isRu ? 'Дата завершения' : 'Finish date';
  String get price => locale.isRu ? 'Стоимость' : 'Price';
  String get type => locale.isRu ? 'Тип' : 'Type';
  String get onlineKataApplication =>
      locale.isRu ? 'Заявка онлайн-ката' : 'Online kata application';
  String get firstRoundCategory =>
      locale.isRu ? 'Категория первого круга' : 'First round category';
  String get chooseCategory =>
      locale.isRu ? 'Выберите категорию' : 'Choose category';
  String get videoUnavailable => locale.isRu
      ? 'Видео недоступно. Проверьте подключение и права доступа.'
      : 'Video unavailable. Check your connection and access.';
  String get videoPrivate => locale.isRu
      ? 'Видео доступно только тренеру участника'
      : 'Video is available only to the participant’s coach';
  String get playPause =>
      locale.isRu ? 'Воспроизвести / пауза' : 'Play / pause';
  String get muteVideo => locale.isRu ? 'Звук' : 'Sound';
  String get fullscreen => locale.isRu ? 'На весь экран' : 'Fullscreen';
  String get exitFullscreen =>
      locale.isRu ? 'Свернуть видео' : 'Exit fullscreen';
  String get uploadCanceled =>
      locale.isRu ? 'Загрузка отменена' : 'Upload canceled';
  String get videoTooLarge => locale.isRu
      ? 'Объём видео превышен. Максимальный размер — 100 МБ.'
      : 'Video size exceeded. The maximum size is 100 MB.';
  String get chooseVideo => locale.isRu ? 'Выбрать видео' : 'Choose video';
  String get videoSelected => locale.isRu ? 'Видео выбрано' : 'Video selected';
  String get continueToPayment =>
      locale.isRu ? 'Перейти к оплате' : 'Continue to payment';
  String get paymentOpenFailed =>
      locale.isRu ? 'Не удалось открыть оплату' : 'Could not open payment';
  String get paymentStarted => locale.isRu
      ? 'Оплата открыта. После успешной оплаты заявка появится в турнире.'
      : 'Payment opened. The application will appear after successful payment.';
  String get bracket => locale.isRu ? 'Сетка' : 'Bracket';
  String get tatami => locale.isRu ? 'Татами' : 'Tatami';
  String get fight => locale.isRu ? 'Бой' : 'Fight';
  String get freePlace => locale.isRu ? 'Свободное место' : 'Free place';
  String get thirdPlace => locale.isRu ? '3 место' : '3rd place';
  String get noGeneratedData =>
      locale.isRu ? 'Данные пока не сгенерированы' : 'No generated data yet';
  String get preliminaryRound =>
      locale.isRu ? 'Предварительный круг' : 'Preliminary round';
  String get finalRound => locale.isRu ? 'Финал' : 'Final';
  String get results => locale.isRu ? 'Результаты' : 'Results';
  String get totalScore => locale.isRu ? 'Сумма' : 'Total';
  String get rank => locale.isRu ? 'Место' : 'Rank';
  String get minScore => locale.isRu ? 'Мин.' : 'Min';
  String get maxScore => locale.isRu ? 'Макс.' : 'Max';
  String get videoUploaded =>
      locale.isRu ? 'Видео загружено' : 'Video uploaded';
  String get videoNotUploaded =>
      locale.isRu ? 'Видео не загружено' : 'Video missing';
  String get uploadFinalVideo =>
      locale.isRu ? 'Загрузить финальное видео' : 'Upload final video';
  String get changeFinalVideo =>
      locale.isRu ? 'Изменить финальное видео' : 'Change final video';
  String get finalVideoUpdated =>
      locale.isRu ? 'Финальное видео обновлено' : 'Final video updated';
  String get placeNumber => locale.isRu ? 'место' : 'place';
  String get detachQuestion =>
      locale.isRu ? 'Открепить ученика?' : 'Detach student?';
  String get detachText => locale.isRu
      ? 'Ученик будет снят с участия в этом турнире.'
      : 'The student will be removed from this tournament.';
  String get examNoStudentsAttached => locale.isRu
      ? 'Ни один ученик не прикреплён. Обновите список и повторите выбор.'
      : 'No students were attached. Refresh the list and select again.';
  String get noAttachOptions =>
      locale.isRu ? 'Нет учеников для прикрепления' : 'No students to attach';
  String get exportReady =>
      locale.isRu ? 'Выгрузка отправлена на backend' : 'Export requested';
  String get fileSaved => locale.isRu ? 'Файл сохранён' : 'File saved';
  String get allPlaces => locale.isRu ? 'Все места' : 'All places';
  String get allExaminers => locale.isRu ? 'Все принимающие' : 'All examiners';
  String get chooseDate => locale.isRu ? 'Выбрать дату' : 'Choose date';
  String get trainerFilter =>
      locale.isRu ? 'Фильтр по тренеру' : 'Coach filter';
  String get documents => locale.isRu ? 'Документы' : 'Documents';
  String get contacts => locale.isRu ? 'Контакты' : 'Contacts';
  String get generalQuestions =>
      locale.isRu ? 'Общие вопросы' : 'General questions';
  String get partnership => locale.isRu
      ? 'Сотрудничество и партнёрство'
      : 'Cooperation and partnership';
  String get trainerSettings =>
      locale.isRu ? 'Настройки тренера' : 'Coach settings';
  String get studentsTournamentAccess => locale.isRu
      ? 'Доступ ученикам заявляться на турнир'
      : 'Allow students to apply for tournaments';
  String get studentsDataAccess =>
      locale.isRu ? 'Доступ учеников к данным' : 'Student access to fight data';
  String get studentsExamAccess => locale.isRu
      ? 'Доступ ученикам заявляться на экзамен'
      : 'Allow students to apply for exams';
  String get settingsSaved =>
      locale.isRu ? 'Настройки сохранены' : 'Settings saved';
  String get settingsSaveFailed => locale.isRu
      ? 'Не удалось сохранить настройки'
      : 'Could not save settings';
  String get settingsLoadFailed => locale.isRu
      ? 'Не удалось загрузить настройки'
      : 'Could not load settings';
  String get inviteStudent =>
      locale.isRu ? 'Пригласить ученика' : 'Invite student';
  String get coachCode => locale.isRu ? 'Код тренера' : 'Coach code';
  String get copyCoachCode => locale.isRu ? 'Копировать код' : 'Copy code';
  String get codeCopied => locale.isRu ? 'Код скопирован' : 'Code copied';
  String get pendingInvitations =>
      locale.isRu ? 'Ожидают приглашения' : 'Pending invitations';
  String get invitationEmails =>
      locale.isRu ? 'Email через запятую' : 'Emails separated by commas';
  String get sendInvitations =>
      locale.isRu ? 'Отправить приглашения' : 'Send invitations';
  String get cancelInvitation =>
      locale.isRu ? 'Отменить приглашение?' : 'Cancel invitation?';
  String get detachStudent =>
      locale.isRu ? 'Открепить ученика' : 'Detach student';
  String get detachStudentConfirm => locale.isRu
      ? 'Открепить ученика от тренера? Аккаунт и история сохранятся.'
      : 'Detach this student from the coach? The account and history will be kept.';
  String get removeDocumentConfirm => locale.isRu
      ? 'Удалить документ при сохранении?'
      : 'Remove this document when saving?';
  String get savedFile => locale.isRu ? 'Файл загружен' : 'File uploaded';
  String get documentRemoved =>
      locale.isRu ? 'Будет удалён' : 'Will be removed';
  String get documentExcluded =>
      locale.isRu ? 'Не участвует в проверке' : 'Excluded from verification';
  String get juniorRankGroup => locale.isRu ? '9–10 кю' : '9–10 kyu';
  String get seniorRankGroup => locale.isRu ? '8–1 кю, дан' : '8–1 kyu, dan';
  String get chiefJudge => locale.isRu ? 'Главный судья' : 'Chief judge';
  String get chiefSecretary =>
      locale.isRu ? 'Главный секретарь' : 'Chief secretary';
  String get regulationDocument => locale.isRu ? 'Положение' : 'Regulations';
  String get applicationDocument =>
      locale.isRu ? 'Заявление' : 'Application form';
  String get weightKg => locale.isRu ? 'кг' : 'kg';
  String get moreRecords => locale.isRu ? 'Показать ещё' : 'Show more';
  String get activeCategories =>
      locale.isRu ? 'Активные категории' : 'Active categories';
  String invitationResult(String status) => switch (status) {
    'queued' => locale.isRu ? 'Письмо поставлено в очередь' : 'Email queued',
    'invalid_email' => locale.isRu ? 'Некорректный email' : 'Invalid email',
    'already_attached' =>
      locale.isRu ? 'Уже ваш ученик' : 'Already your student',
    'unavailable' =>
      locale.isRu ? 'Аккаунт нельзя прикрепить' : 'Account cannot be attached',
    _ => locale.isRu ? 'Не удалось отправить' : 'Sending failed',
  };
  String studentDocumentIssue(String? key) => switch (key) {
    'documentIssuePassport' =>
      locale.isRu ? 'Паспорт не подтверждён' : 'Passport not verified',
    'documentIssueBrand' =>
      locale.isRu
          ? 'Медсправка не подтверждена'
          : 'Medical certificate not verified',
    'documentIssueInsurance' =>
      locale.isRu ? 'Страховка не подтверждена' : 'Insurance not verified',
    'documentIssueInsuranceDate' =>
      locale.isRu ? 'Не указан срок страховки' : 'Insurance expiry missing',
    'documentIssueInsuranceExpired' =>
      locale.isRu ? 'Страховка просрочена' : 'Insurance expired',
    'documentIssueIkoCard' =>
      locale.isRu ? 'IKO не подтверждена' : 'IKO not verified',
    'documentIssueCertificate' =>
      locale.isRu ? 'Сертификат не подтверждён' : 'Certificate not verified',
    _ => notConfirmed,
  };
  String get notificationLinkError =>
      locale.isRu ? 'Не удалось открыть ссылку' : 'Unable to open the link';
  String get emptyRating => locale.isRu
      ? 'Нет результатов для выбранных фильтров'
      : 'No results for these filters';

  String get education => locale.isRu ? 'Обучение' : 'Education';
  String educationSection(String id, {bool ownWorks = false}) => switch (id) {
    'kata_attestation' => locale.isRu ? 'Ката: аттестация' : 'Grading kata',
    'kihon' => locale.isRu ? 'Кихон' : 'Kihon',
    'ido_geiko' => locale.isRu ? 'Идо-гейко' : 'Ido geiko',
    'competition' => locale.isRu ? 'Соревновательные ката' : 'Competition kata',
    'works' =>
      ownWorks
          ? (locale.isRu ? 'Ката разбор' : 'Kata review')
          : (locale.isRu ? 'Работы учеников' : 'Student works'),
    _ => education,
  };
  String get educationEmpty =>
      locale.isRu ? 'Нет доступных записей' : 'No available records';
  String get bracketRounds => locale.isRu ? 'Раунды' : 'Rounds';
  String get bracketOverview => locale.isRu ? 'Вся сетка' : 'Full bracket';
  String get fitBracket => locale.isRu ? 'Показать целиком' : 'Fit bracket';
  String get zoomIn => locale.isRu ? 'Увеличить' : 'Zoom in';
  String get zoomOut => locale.isRu ? 'Уменьшить' : 'Zoom out';
  String get educationLoadFailed => locale.isRu
      ? 'Не удалось загрузить обучение'
      : 'Unable to load education';
  String get educationWaiting =>
      locale.isRu ? 'Ожидает проверки' : 'Awaiting review';
  String get educationReviewed => locale.isRu ? 'Проверено' : 'Reviewed';
  String get educationUnpaid => locale.isRu ? 'Не оплачено' : 'Unpaid';
  String get educationComment => locale.isRu ? 'Комментарий' : 'Comment';
  String get educationPoint =>
      locale.isRu ? 'Балл в динамике' : 'Performance score';
  String get educationDetailPoint =>
      locale.isRu ? 'Детальный разбор' : 'Detailed analysis score';
  String get educationRecommendation =>
      locale.isRu ? 'Рекомендация' : 'Recommendation';

  String get retry => locale.isRu ? 'Повторить' : 'Retry';
  String get notifications => locale.isRu ? 'Уведомления' : 'Notifications';
  String get important => locale.isRu ? 'Важные' : 'Important';
  String get fromProject => locale.isRu ? 'От проекта' : 'From project';
  String get markAllAsRead =>
      locale.isRu ? 'Отметить все как прочитанные' : 'Mark all as read';
  String get markAsRead =>
      locale.isRu ? 'Отметить как прочитанное' : 'Mark as read';
  String get details => locale.isRu ? 'Подробнее' : 'Details';
  String get newLabel => locale.isRu ? 'Новое' : 'New';
  String get systemLabel => locale.isRu ? 'Система' : 'System';
  String get emptyNotifications =>
      locale.isRu ? 'Уведомлений пока нет' : 'No notifications yet';
  String get minutesAgo => locale.isRu ? 'мин назад' : 'min ago';
  String get hoursAgo => locale.isRu ? 'ч назад' : 'h ago';
  String get daysAgo => locale.isRu ? 'дня назад' : 'd ago';

  String get videoUploadFailed => locale.isRu
      ? 'Не удалось загрузить видео. Проверьте соединение и повторите.'
      : 'Video upload failed. Check your connection and retry.';
  String get videoProcessing =>
      locale.isRu ? 'Обработка видео…' : 'Processing video…';
  String get loadMore => locale.isRu ? 'Показать ещё' : 'Load more';
  String get paymentApplications =>
      locale.isRu ? 'Заявки и оплата' : 'Applications and payments';
  String get paymentCheckFailed => locale.isRu
      ? 'Не удалось проверить оплату. Повторите обновление.'
      : 'Unable to check payment. Refresh to retry.';
  String get paymentRetryTitle =>
      locale.isRu ? 'Разрешить новую заявку' : 'Allow a new application';
  String get paymentRetryText => locale.isRu
      ? 'Платёж отменён. Разрешить новую заявку с повторным выбором видео и оплатой?'
      : 'The payment was canceled. Allow a new application with a new video selection and payment?';
  String get paymentConflictHelp => locale.isRu
      ? 'Заявка не прикреплена. Обратитесь к организатору для проверки платежа и возврата. Повторно не оплачивайте.'
      : 'The application was not enrolled. Contact the organizer to review the payment and refund. Do not pay again.';
  String get firstVideoReady =>
      locale.isRu ? '1-й круг: загружено' : 'Round 1: uploaded';
  String get firstVideoMissing =>
      locale.isRu ? '1-й круг: нет видео' : 'Round 1: no video';
  String get finalVideoReady =>
      locale.isRu ? 'Финал: загружено' : 'Final: uploaded';
  String get finalVideoMissing =>
      locale.isRu ? 'Финал: нет видео' : 'Final: no video';
  String educationPaymentStatus(String status) => status == 'fulfilled'
      ? (locale.isRu ? 'Оплачено' : 'Paid')
      : kataPaymentStatus(status);

  String kataPaymentStatus(String status) => switch (status) {
    'fulfilled' =>
      locale.isRu ? 'Оплачено · ученик прикреплён' : 'Paid · student enrolled',
    'canceled' => locale.isRu ? 'Платёж отменён' : 'Payment canceled',
    'conflict' =>
      locale.isRu ? 'Нужна проверка платежа' : 'Payment review required',
    'detached' =>
      locale.isRu
          ? 'Оплаченная заявка откреплена'
          : 'Paid application detached',
    'pending' => locale.isRu ? 'Ожидание оплаты' : 'Awaiting payment',
    _ => locale.isRu ? 'Проверяем платёж' : 'Checking payment',
  };
}
