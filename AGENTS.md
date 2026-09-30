# Архитектура работы с форком Codex Switcher (bnku/codex-switcher)

## 1. Структура веток
- `upstream/main` — неприкосновенный официальный апстрим (`Lampese/codex-switcher`).
- `feature/*` и `fix/*` — **атомарные PR-ветки**. Каждая фича или багфикс разрабатывается в строгой изоляции, отпочковываясь от свежего `upstream/main`. Они отправляются в апстрим через отдельные PR и не содержат изменений из других PR.
  - Текущие активные PR:
    - PR #192: `feature/auto-session-recovery` (Auto session recovery & smart quota prioritization)
    - PR #198: `fix/linux-gtk-menu-resize` (Linux GTK menu removal & frameless window resize borders)
- `fork/enhanced-infra` — ветка инфраструктуры форка (скрипт сборки `scripts/rebuild-enhanced.sh`, GitHub Actions релизов `.github/workflows/enhanced-release.yml`, правила агента `AGENTS.md`).
- `enhanced` — **главная интеграционная ветка форка** (установлена default branch на GitHub в `bnku/codex-switcher`).
  - Эта ветка пересоздается поверх `upstream/main` путем автоматического мерджа всех активных PR-веток (`feature/*`, `fix/*`, `fork/enhanced-infra`).
  - Из ветки `enhanced` собирается рабочий бинарник пользователя для повседневного использования (`~/.local/bin/codex-switcher`).

---

## 2. Алгоритм работы агента при любых задачах

### А. Если нужно внести правки в существующий PR (например, PR #192 или PR #198):
1. Переключиться на соответствующую атомарную ветку (`git checkout feature/auto-session-recovery` или `git checkout fix/linux-gtk-menu-resize`).
2. Внести необходимые изменения, проверить тесты (`cargo test`, `pnpm build`, `cargo fmt`).
3. Закоммитить и запушить в `origin/<branch>`. GitHub автоматически обновит соответствующий PR в апстриме.
4. Запустить `./scripts/rebuild-enhanced.sh` для пересборки интеграционной ветки `enhanced` и обновления локального бинарника в `~/.local/bin/codex-switcher`.

### Б. Если нужно разработать новую фичу или поправить независимый баг в апстриме:
1. Подтянуть апстрим: `git fetch upstream main`.
2. Создать новую чистую ветку от `upstream/main`:
   `git checkout -b <feature-or-fix-branch-name> upstream/main`.
3. Реализовать изменения, протестировать (`pnpm build`, `cargo test`, `cargo fmt`).
4. Запушить в форк: `git push -u origin <branch>`.
5. Открыть PR в `Lampese/codex-switcher` через `gh pr create`.
6. Добавить новую ветку в массив `FEATURE_BRANCHES` в `scripts/rebuild-enhanced.sh` (в ветке `fork/enhanced-infra`).
7. Запустить `./scripts/rebuild-enhanced.sh`, чтобы обновить `enhanced` и получить готовый билд со всеми фичами.

### В. Если нужно пересобрать текущий билд пользователя:
- Запустить `./scripts/rebuild-enhanced.sh`.
- Скрипт проверит статус, подтянет апстрим, накатит все ветки, проверит тесты, запушит в `origin/enhanced`, соберет релизный бинарь и установит его в `~/.local/bin/codex-switcher` и `./codex-switcher`.
