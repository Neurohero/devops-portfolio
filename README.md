# DevOps portfolio — Максим Попов

Примеры конфигураций в том виде, в каком я делаю их в работе. Всё написано
с нуля под этот репозиторий: не выгрузка чужой инфраструктуры, без реальных
хостов и секретов.

## helm/webapp — чарт для stateless-сервиса

Чарт, который не стыдно отдать в прод:

- **Выкатка без просадки:** `maxUnavailable: 0`, раздельные startup/readiness/liveness
  пробы, `preStop`-пауза, чтобы балансировщик успел убрать под до SIGTERM.
- **Readiness без проверки зависимостей** — падение БД или кэша не снимает из
  балансировки все поды разом.
- **Память:** `GOMEMLIMIT` ≈ 90% от лимита контейнера — GC срабатывает раньше
  OOMKiller'а; CPU limit не задан сознательно (throttling).
- **Надёжность:** PodDisruptionBudget, `topologySpreadConstraints` по нодам, HPA.
- **Безопасность:** non-root, read-only root FS, `drop: ALL`, seccomp; секреты —
  только ссылкой на внешний Secret (Vault / External Secrets), не в values.
- **Конфиг:** ConfigMap с `checksum`-аннотацией — изменение конфига само
  перекатывает поды.

```sh
helm lint helm/webapp
helm template demo helm/webapp -f helm/webapp/values-prod.yaml
```

## pg-diagnostics — стек расследования нагрузки на PostgreSQL

Отвечает на вопросы «что грузило базу вчера с 14 до 15» и «кто кого держал
на блокировке»:

- **pg_profile** в отдельной БД-репозитории снимает профили нагрузки по
  расписанию; `sh report.sh FROM TO` строит HTML-отчёт за любой интервал.
- **TimescaleDB** хранит частые срезы ожиданий блокировок (кто ждёт, кто
  держит, сколько, какой запрос) с автоудалением через 14 дней.
- **Grafana** с готовым дашбордом: блокировки во времени, «кто кого ждал»,
  топ запросов из `pg_stat_statements`.
- Наблюдаемую БД стек только читает — отдельной ролью с `pg_monitor`,
  без суперюзера; расширение pg_profile ставится с проверкой sha256.

```sh
cd pg-diagnostics
cp .env.example .env            # поменять пароли
docker compose --profile demo up -d --build   # demo — нагрузка pgbench на демо-БД
# Grafana: http://localhost:3000 (admin / пароль из .env)
sh report.sh "2026-09-28 10:00" "2026-09-28 12:00" > report.html
```

Чтобы смотреть свою базу, а не демо: убрать сервис `target`, на своём
сервере создать роль из `target/init/01-monitoring-role.sh` и поправить
адрес в `repository/init/010-diagnostics.sh`.
