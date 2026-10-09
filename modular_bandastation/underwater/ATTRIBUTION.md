# Происхождение ресурсов StationTrauma

Существующие ресурсы BandaStation сохраняют свои уведомления. Следующие DMI скопированы без изменения.

| Локальный файл | Источник и исходный путь |
| --- | --- |
| `icons/ocean_flora.dmi` | CeladonSS13/Nodalec, `87eb7f807d12ecc9e5c1d5ba5cf32fee1da774e9`, `modular_nova/modules/liquids/icons/obj/flora/ocean_flora.dmi` |
| `icons/scrap.dmi` | Тот же репозиторий и commit, `modular_nova/modules/liquids/icons/obj/flora/scrap.dmi` |
| `../underwater_machinery/pumps/icons/liquid_pump.dmi` | CeladonSS13/Skyrat, `378171fad9f7981fd68b8a32586a25bf38106e8a`, `modular_nova/modules/liquids/icons/obj/structures/liquid_pump.dmi` |
| `../underwater_machinery/pumps/icons/drains.dmi` | Тот же репозиторий и commit, `modular_nova/modules/liquids/icons/obj/structures/drains.dmi` |
| `../underwater_machinery/reactor/icons/rbmk.dmi` | BeeStation/NSV13, `69565b730fdf45c09861dfca6c669b67f8601a71`, `nsv13/icons/obj/machinery/rbmk.dmi` |
| `../underwater_machinery/reactor/icons/control_rod.dmi` | Тот же репозиторий и commit, `nsv13/icons/obj/control_rod.dmi` |

Авторы: участники CeladonSS13/Nodalec, CeladonSS13/Skyrat и их upstream-проектов. История прежнего пути `modular_skyrat/` ведёт к [Liquids system, Azarak, co-author Gandalf](https://github.com/CeladonSS13/Skyrat/commit/20db06c6d09940270713992d60d556ffd9c086ed); для drains также есть [изменение Tastyfish](https://github.com/CeladonSS13/Skyrat/commit/aed24e2da462e3db36c88d9e7887d302972a1117). Перенос каталога в `modular_nova/` выполнен Giz. Это авторы обнаруженной истории интеграции; индивидуальное авторство каждого пикселя из неё не устанавливается.

Согласно README доноров, ассеты распространяются по **CC BY-SA 3.0**, если не указано иное. Отдельных уведомлений для перечисленных DMI в полученных файлах не найдено. Изображения используются без изменений; уведомление и ShareAlike необходимо сохранять при дальнейшем распространении.

- [Nodalec README на выбранном commit](https://github.com/CeladonSS13/Nodalec/blob/87eb7f807d12ecc9e5c1d5ba5cf32fee1da774e9/README.md)
- [Skyrat README на выбранном commit](https://github.com/CeladonSS13/Skyrat/blob/378171fad9f7981fd68b8a32586a25bf38106e8a/README.md)
- [NSV13 README на выбранном commit](https://github.com/BeeStation/NSV13/blob/69565b730fdf45c09861dfca6c669b67f8601a71/README.md)
- [CC BY-SA 3.0 и текст лицензии](https://creativecommons.org/licenses/by-sa/3.0/)

История DMI реактора NSV ведёт к изменениям Kmc2000: [первоначальная версия](https://github.com/BeeStation/NSV13/commit/d258b8d2fd99a510aaa4b4a1ebac6b0ab5b2fbe0), [обновление интерфейсов и топливного бассейна](https://github.com/BeeStation/NSV13/commit/e3540f769f926678764426ec267c46d38a3e10da). Авторы ресурсов — участники NSV13 и его upstream; история интеграции не устанавливает авторство каждого пикселя. README NSV распространяет иконки по CC BY-SA 3.0, если не указано иное. Оба DMI перенесены побайтно; Git blob SHA соответствуют донору. `control_rod.dmi` используется и для кассеты (`irradiated`), и для управляющего стержня (`normal`), как в исходных типах NSV.

Логика насосов написана для BandaStation, использует её floodwater API и штатное питание TG. Система жидкостей доноров не переносилась. Идея разборки подводного металлолома основана на `ocean_flora.dm` Nodalec; реализация адаптирована к современному `welder_act` TG и не использует рекурсивное обслуживание сваркой. Код распространяется по лицензии проекта AGPL-3.0.
