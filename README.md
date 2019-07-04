**Информация/особенности (в сравнении с Levels Ranks) статистики:**

 - Поддержка только CS:GO.
 - Статистики работает на основе формулы ELO [Levels Ranks](https://github.com/levelsranks/levels-ranks-core). Суть его в том, что вы получаете среднее звание и 1000 очков опыта. В зависимости от того, насколько хорошо вы играете зависит ваше звание.
 - Статистика работает только с MySQL и рассчитана на работу с ВЕБом, который будет сделан Мостис для LR и позже адаптирован под FPS.
 - Количество рангов не ограничено. Настройка производится напрямую с БД или через ВЕБ.
 - Совмещенная база данных для нескольких серверов (по принципу випки от Рико) с нормальной структурой.
 - Статистика по оружию хранится в отдельной таблице, из-за чего при выходе нового оружия изменять плагин и БД не придется.
 - Попытка исправить превосходство новых игроков перед старыми в получении поинтов.
 - Начисление стрика возможно только в течении 10 сек после убийства, после чего идет обнуление.
 - Можно установить лимит обнуления статистики по времени для пользователя.
 - Минимизирована информация об получаемых очках.
 - Важной особенностью данного плагина можно отметить неизменное API и переводы при обновлениях. =)

 [**_Список модулей к статистике_**](https://gitlab.com/OkyHp/fire-players-stats/tree/master/FPS_Modules)

 Спасибо за идеии в реализации: [Разработчикам LR](https://github.com/orgs/levelsranks/people), [Someone](https://hlmod.ru/members/someone.73313/).

---

**Требования**

  - [**Sourcemod 1.9+**](https://www.sourcemod.net/downloads.php?branch=stable)
  - [**CS:GO Colors**](https://hlmod.ru/resources/inc-cs-go-colors.1009/)
  - [**SteamWorks**](http://users.alliedmods.net/~kyles/builds/SteamWorks/) (Опционально)

---

**Команды плагина:**

**sm_pos**, **sm_position** - Позиция игрока на сервере. \
**sm_stats**, **sm_rank**, **sm_fps** - Главное меню статистики. \
**sm_top** - Топ лучших игроков. \
**sm_toptime** - Топ игроков по наиграному времени.

---

**Установка**

 1. Скачайте актуальную версию с репозитория.
 2. Скомпилируйте плагин.
 3. Поместите содержимое репозитория и скомпилированный плагин по нужным директориям.
 4. Добавьте секцию с вашими настройками БД в `addons/sourcemod/configs/databases.cfg`:
	```
	"fire_players_stats"
	{
		"driver"			"mysql"
		"host"				""
		"database"			""
		"user"				""
		"pass"				""
		"port"				"3306"
	}
	```
 5. Запустите сервер, чтобы плагин создал нужные таблицы в БД.
 6. Загрузите настройку рангов, отправив SQL запрос в БД, предварительно откорректировав его под ваши нужды:
	```sql
	INSERT INTO `fps_ranks` (`rank_id`, `rank_name`, `points`) 
	VALUES 
		('1', 'Silver I', '0'),
		('1', 'Silver II', '700'), 
		('1', 'Silver III', '800'), 
		('1', 'Silver IV', '850'), 
		('1', 'Silver Elite', '900'), 
		('1', 'Silver Elite Master', '925'), 
		('1', 'Gold Nova I', '950'), 
		('1', 'Gold Nova II', '975'), 
		('1', 'Gold Nova III', '1000'), 
		('1', 'Gold Nova Master', '1100'), 
		('1', 'Master Guardian I', '1250'), 
		('1', 'Master Guardian II', '1400'), 
		('1', 'Master Guardian Elite', '1600'), 
		('1', 'Distinguished Master Guardian', '1800'), 
		('1', 'Legendary Eagle', '2100'), 
		('1', 'Legendary Eagle Master', '2400'), 
		('1', 'Supreme Master First Class', '3000'), 
		('1', 'The Global Elite', '4000');
	```

Тема на [HLmod](https://hlmod.ru/resources/fire-players-stats.1232/).