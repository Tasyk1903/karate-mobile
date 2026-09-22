import 'app_locale.dart';

extension StaffStrings on AppStrings {
  String get adultMale => locale.isRu ? 'Мужской' : 'Male';
  String get adultFemale => locale.isRu ? 'Женский' : 'Female';
  String get sortStudentName =>
      locale.isRu ? 'По имени ученика' : 'By student name';
  String get scoreRange => locale.isRu
      ? 'Оценка должна быть от 0 до 10 с шагом 0,1.'
      : 'Enter a score from 0 to 10 in steps of 0.1.';
  String get saving => locale.isRu ? 'Сохранение…' : 'Saving…';
  String get close => locale.isRu ? 'Закрыть' : 'Close';
  String get upload => locale.isRu ? 'Загрузить' : 'Upload';
  String get confirm => locale.isRu ? 'Подтвердить' : 'Confirm';
  String get judging => locale.isRu ? 'Судейство' : 'Judging';
  String get masterReviews => locale.isRu ? 'Разборы' : 'Reviews';
  String get ownScore => locale.isRu ? 'Моя оценка' : 'My score';
  String get savedScore => locale.isRu ? 'Сохранено' : 'Saved';
  String get saveDraft => locale.isRu ? 'Сохранить черновик' : 'Save draft';
  String get publishReview => locale.isRu ? 'Опубликовать' : 'Publish';
  String get reopenReview =>
      locale.isRu ? 'Вернуть в ожидание' : 'Return to pending';
  String get reopenQuestion => locale.isRu
      ? 'Скрыть результат разбора до повторной публикации?'
      : 'Hide the review until it is published again?';
  String get unsavedQuestion => locale.isRu
      ? 'Выйти без сохранения изменений?'
      : 'Discard unsaved changes?';
  String get scoreConflict => locale.isRu
      ? 'Оценка изменилась. Обновите таблицу; ваш ввод сохранён в поле.'
      : 'The score has changed. Refresh the table; your input remains in the field.';
  String get refreshRecord =>
      locale.isRu ? 'Обновить данные' : 'Refresh record';
  String get allWorks => locale.isRu ? 'Все' : 'All';
  String get pendingWorks => locale.isRu ? 'Ожидают' : 'Pending';
  String get reviewedWorks => locale.isRu ? 'Проверены' : 'Reviewed';
  String get emptyStaffList =>
      locale.isRu ? 'Записи не найдены' : 'No records found';
  String get judgeRole => locale.isRu ? 'Судья' : 'Judge';
  String get masterRole => locale.isRu ? 'Мастер' : 'Master';
  String get judgePosition =>
      locale.isRu ? 'Судейская позиция' : 'Judging position';
  String get refereePosition => locale.isRu ? 'Рефери' : 'Referee';
  String get noPosition => locale.isRu ? 'Не назначена' : 'Not assigned';
  String get photoSelected =>
      locale.isRu ? 'Выбран новый файл' : 'New file selected';
  String get allTournaments => locale.isRu ? 'Все турниры' : 'All tournaments';
  String get sortTatami => locale.isRu ? 'По татами' : 'By tatami';
  String get sortDefault => locale.isRu ? 'По порядку' : 'By order';
  String staffField(String key) {
    const ru = {
      'description': 'Комментарий проверяющего',
      'point': 'Балл в динамике',
      'detail_point': 'Балл детального разбора',
      'recommendation': 'Рекомендации',
      'first_name': 'Имя',
      'last_name': 'Фамилия',
      'patronymic': 'Отчество',
      'email': 'Email',
      'gender': 'Пол',
      'birthday': 'Дата рождения',
      'rang': 'Кю / дан',
      'weight': 'Вес, кг',
      'city_training': 'Город тренировок',
      'number_brand': 'Номер справки',
      'number_iko': 'Номер IKO',
      'number_certificate': 'Номер сертификата',
      'last_examination_date': 'Дата последнего экзамена',
      'last_examination_city': 'Город экзамена',
      'last_receiving': 'Принимающий экзамен',
      'passport': 'Паспорт',
      'brand': 'Медсправка',
      'insurance': 'Страховка',
      'iko_card': 'IKO-карта',
      'certificate': 'Сертификат',
      'avatar': 'Аватар',
    };
    const en = {
      'description': 'Reviewer comment',
      'point': 'Performance mark',
      'detail_point': 'Detailed analysis mark',
      'recommendation': 'Recommendations',
      'first_name': 'First name',
      'last_name': 'Last name',
      'patronymic': 'Middle name',
      'email': 'Email',
      'gender': 'Gender',
      'birthday': 'Date of birth',
      'rang': 'Kyu / dan',
      'weight': 'Weight, kg',
      'city_training': 'Training city',
      'number_brand': 'Medical certificate number',
      'number_iko': 'IKO number',
      'number_certificate': 'Certificate number',
      'last_examination_date': 'Last examination date',
      'last_examination_city': 'Examination city',
      'last_receiving': 'Examiner',
      'passport': 'Passport',
      'brand': 'Medical certificate',
      'insurance': 'Insurance',
      'iko_card': 'IKO card',
      'certificate': 'Certificate',
      'avatar': 'Avatar',
    };
    return (locale.isRu ? ru : en)[key] ?? key;
  }
}
