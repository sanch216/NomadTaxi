/// Simple localization strings for the app.
/// Supports: ru (Русский), ky (Кыргызча), en (English).
class AppStrings {
  AppStrings._();

  static const Map<String, Map<String, String>> _strings = {
    // Home screen
    'where_to': {'ru': 'Куда едем?', 'ky': 'Кайда барабыз?', 'en': 'Where to?'},
    'now': {'ru': 'Сейчас', 'ky': 'Азыр', 'en': 'Now'},
    'from': {'ru': 'Откуда?', 'ky': 'Кайдан?', 'en': 'From?'},
    'to': {'ru': 'Куда?', 'ky': 'Кайда?', 'en': 'Where to?'},
    'pickup_point': {
      'ru': 'Точка отправления',
      'ky': 'Жөнөө пункту',
      'en': 'Pickup point',
    },
    'suggested_places': {
      'ru': 'Предложенные места',
      'ky': 'Сунушталган жерлер',
      'en': 'Suggested places',
    },
    'my_location': {
      'ru': 'Моё местоположение',
      'ky': 'Менин жайгашкан жерим',
      'en': 'My location',
    },
    'current_gps': {
      'ru': 'Текущая GPS позиция',
      'ky': 'Учурдагы GPS позиция',
      'en': 'Current GPS position',
    },
    'choose_ride': {
      'ru': 'Выберите класс',
      'ky': 'Классты тандаңыз',
      'en': 'Choose a ride',
    },
    'cash': {'ru': 'Наличные', 'ky': 'Накталай', 'en': 'Cash'},
    'add_comment': {
      'ru': 'Добавить комментарий',
      'ky': 'Комментарий кошуу',
      'en': 'Add a comment',
    },
    'request_taxi': {
      'ru': 'Заказать AIS-TAXI',
      'ky': 'AIS-TAXI чакыруу',
      'en': 'Request AIS-TAXI',
    },
    'return_to_order': {
      'ru': 'Вернуться к заказу',
      'ky': 'Заказга кайтуу',
      'en': 'Return to order',
    },

    // Car classes
    'economy': {'ru': 'Эконом', 'ky': 'Эконом', 'en': 'Economy'},
    'comfort': {'ru': 'Комфорт', 'ky': 'Комфорт', 'en': 'Comfort'},
    'business': {'ru': 'Бизнес', 'ky': 'Бизнес', 'en': 'Business'},
    'min': {'ru': 'мин', 'ky': 'мин', 'en': 'min'},

    // Drawer
    'my_rides': {
      'ru': 'Мои поездки',
      'ky': 'Менин сапарларым',
      'en': 'My rides',
    },
    'earnings': {'ru': 'Мой доход', 'ky': 'Менин кирешем', 'en': 'My earnings'},
    'payment_methods': {
      'ru': 'Способы оплаты',
      'ky': 'Төлөм ыкмалары',
      'en': 'Payment methods',
    },
    'profile_settings': {
      'ru': 'Настройки профиля',
      'ky': 'Профиль жөндөөлөрү',
      'en': 'Profile settings',
    },
    'dark_theme': {
      'ru': 'Тёмная тема',
      'ky': 'Караңгы тема',
      'en': 'Dark theme',
    },
    'light_theme': {
      'ru': 'Светлая тема',
      'ky': 'Жарык тема',
      'en': 'Light theme',
    },
    'support': {'ru': 'Техподдержка', 'ky': 'Колдоо кызматы', 'en': 'Support'},
    'choose_language': {
      'ru': 'Выберите язык',
      'ky': 'Тилди тандаңыз',
      'en': 'Choose language',
    },

    // Profile
    'profile': {'ru': 'Профиль', 'ky': 'Профиль', 'en': 'Profile'},
    'name': {'ru': 'Имя', 'ky': 'Аты', 'en': 'Name'},
    'phone': {'ru': 'Телефон', 'ky': 'Телефон', 'en': 'Phone'},
    'rating': {'ru': 'Рейтинг', 'ky': 'Рейтинг', 'en': 'Rating'},
    'logout': {'ru': 'Выйти', 'ky': 'Чыгуу', 'en': 'Log out'},
    'not_specified': {
      'ru': 'Не указано',
      'ky': 'Көрсөтүлгөн эмес',
      'en': 'Not specified',
    },
    'profile_updated': {
      'ru': 'Профиль обновлён',
      'ky': 'Профиль жаңыланды',
      'en': 'Profile updated',
    },
    'save_error': {
      'ru': 'Не удалось сохранить',
      'ky': 'Сактоо мүмкүн болгон жок',
      'en': 'Failed to save',
    },

    // History
    'no_rides_yet': {
      'ru': 'Поездок пока нет',
      'ky': 'Сапарлар жок',
      'en': 'No rides yet',
    },
    'history_load_error': {
      'ru': 'Не удалось загрузить историю',
      'ky': 'Тарыхты жүктөө мүмкүн болгон жок',
      'en': 'Failed to load history',
    },
    'completed': {'ru': 'Завершена', 'ky': 'Аяктады', 'en': 'Completed'},

    // Payments
    'add_card': {'ru': 'Добавить карту', 'ky': 'Карта кошуу', 'en': 'Add card'},
    'comment_hint': {
      'ru': 'Например: встречайте у подъезда №3',
      'ky': 'Мисалы: 3-кире бериштен тосуп алыңыз',
      'en': 'Example: meet me at entrance #3',
    },
    'selected': {'ru': 'Выбрано', 'ky': 'Тандалды', 'en': 'Selected'},
    'coming_soon': {
      'ru': 'Скоро будет доступно',
      'ky': 'Жакында жеткиликтүү болот',
      'en': 'Coming soon',
    },
    'user': {'ru': 'Пользователь', 'ky': 'Колдонуучу', 'en': 'User'},
    'som': {'ru': 'сом', 'ky': 'сом', 'en': 'som'},

    // Driver panel
    'go_online': {
      'ru': 'Выйти на линию',
      'ky': 'Онлайнго чыгуу',
      'en': 'Go Online',
    },
    'go_offline': {
      'ru': 'Уйти с линии',
      'ky': 'Офлайнга чыгуу',
      'en': 'Go Offline',
    },
    'offline_label': {'ru': 'Оффлайн', 'ky': 'Офлайн', 'en': 'Offline'},
    'online_label': {'ru': 'Онлайн', 'ky': 'Онлайн', 'en': 'Online'},
    'you_offline': {
      'ru': 'Вы не на линии',
      'ky': 'Барбайсыз',
      'en': 'You are offline',
    },
    'go_online_hint': {
      'ru': 'Выйдите на линию, чтобы получать заказы',
      'ky': 'Заказ алуу үчүн онлайнга чыгыңыз',
      'en': 'Go online to start accepting rides',
    },
    'searching_orders': {
      'ru': 'В поиске заказов',
      'ky': 'Заказдарды издөө',
      'en': 'Searching orders',
    },
    'waiting_passengers': {
      'ru': 'Ожидание пассажиров...',
      'ky': 'Жолоочуларды күтүү...',
      'en': 'Waiting for passengers...',
    },
    'new_request_label': {
      'ru': 'Новый заказ',
      'ky': 'Жаны заказ',
      'en': 'New request',
    },
    'on_ride_label': {'ru': 'В поездке', 'ky': 'Сапарда', 'en': 'On ride'},
    'completed_label': {'ru': 'Завершено', 'ky': 'Аяктады', 'en': 'Completed'},
    'error_label': {'ru': 'Ошибка', 'ky': 'Ката', 'en': 'Error'},
    'dismiss': {'ru': 'Закрыть', 'ky': 'Жабуу', 'en': 'Dismiss'},

    // Driver profile
    'vehicle_details': {
      'ru': 'Данные автомобиля',
      'ky': 'Унаа маалыматы',
      'en': 'Vehicle details',
    },
    'car_model': {
      'ru': 'Модель автомобиля',
      'ky': 'Унаа моделу',
      'en': 'Car model',
    },
    'license_plate': {
      'ru': 'Номерной знак',
      'ky': 'Мамлекеттик номер',
      'en': 'License plate',
    },
    'rides_count': {'ru': 'Поездки', 'ky': 'Сапарлар', 'en': 'Rides'},
    'map': {'ru': 'Карта', 'ky': 'Карта', 'en': 'Map'},
    'theme': {'ru': 'Тема', 'ky': 'Тема', 'en': 'Theme'},
    'language': {'ru': 'Язык', 'ky': 'Тил', 'en': 'Language'},
    // Removed duplicate dark_theme and light_theme

    // Ride complete card
    'completed_ride': {
      'ru': 'Поездка завершена!',
      'ky': 'Сапар аяктады!',
      'en': 'Ride complete!',
    },
    'you_earned': {
      'ru': 'Вы заработали',
      'ky': 'Сиз таптыңыз',
      'en': 'You earned',
    },
    'rate_passenger': {
      'ru': 'Оцените пассажира',
      'ky': 'Жолоочуну баалаңыз',
      'en': 'Rate passenger',
    },

    // Incoming ride sheet
    // Removed duplicate pickup_point
  };

  /// Lookup a translated string by key and locale (fallback: ru).
  static String get(String key, String locale) {
    return _strings[key]?[locale] ?? _strings[key]?['ru'] ?? key;
  }
}
