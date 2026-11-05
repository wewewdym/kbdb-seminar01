# Короткие команды для работы со стеком. Запуск: make <цель>
.PHONY: up down reset psql run logs

up:            ## поднять стек
	docker compose up -d

down:          ## остановить стек (данные сохраняются)
	docker compose down

reset:         ## снести том и перезагрузить датасет с нуля
	docker compose down -v
	docker compose up -d

psql:          ## открыть консоль psql
	docker compose exec postgres psql -U student -d plant

run:           ## прогнать ваш файл с решениями и показать результаты
	docker compose exec -T postgres psql -U student -d plant -v ON_ERROR_STOP=0 < sql/seminar01.sql

logs:          ## логи PostgreSQL
	docker compose logs -f postgres
