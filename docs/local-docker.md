# Local Setup — Docker Compose

Runs the full stack locally using Docker Compose: Spring Boot app, MySQL, Prometheus, and Grafana.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         Docker Network                            │
│                                                                   │
│  ┌──────────────────┐       ┌──────────────────┐                 │
│  │   Spring Boot    │──────►│      MySQL        │                 │
│  │   :8080          │       │      :3306        │                 │
│  └────────┬─────────┘       └──────────────────┘                 │
│           │ /actuator/prometheus                                  │
│           ▼                                                       │
│  ┌──────────────────┐       ┌──────────────────┐                 │
│  │   Prometheus     │──────►│     Grafana       │                 │
│  │   :9090          │       │     :3000         │                 │
│  └──────────────────┘       └──────────────────┘                 │
│                                                                   │
└──────────────────────────┬───────────────────────────────────────┘
                           │
          ┌────────────────┼──────────────────┐
          ▼                ▼                  ▼
   localhost:8080    localhost:9090     localhost:3000
   (API requests)   (Prometheus UI)   (Grafana dashboards)
```

All services run inside the same Docker network and communicate using service names as hostnames. On startup, Flyway automatically runs the database migration, creating the `user` table and seeding an initial record. Prometheus starts only after the app is healthy, and Grafana's datasource and dashboard are provisioned automatically — no manual setup needed.

---

## Setup

**1. Configure environment variables**

All variables are defined in `.env`. Never commit this file — it is listed in `.gitignore`. Use `.env.example` as the template.

| Variable | Description | Example |
|---|---|---|
| `MYSQL_ROOT_PASSWORD` | MySQL root password | `dev` |
| `MYSQL_DATABASE` | Database name | `challenge` |
| `MYSQL_USERNAME` | MySQL username | `root` |
| `GRAFANA_ADMIN_USER` | Grafana admin username | `admin` |
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin password | `admin` |

```bash
cp .env.example .env
```

Edit `.env` with your preferred values.

**2. Start the stack**
```bash
docker compose up --build
```

The first run takes a few minutes — Maven downloads all dependencies inside the build container. Subsequent builds are faster due to layer caching.

---

## Testing the API

```bash
# Fetch a user by ID
curl "http://localhost:8080/user?id=1"
# Greetings from Crewmeister, Alice!

# Create a new user
curl -X POST http://localhost:8080/user \
  -H "Content-Type: application/json" \
  -d '{"name": "Muhammad"}'
# Greetings from Crewmeister, Muhammad!

# Health check
curl http://localhost:8080/actuator/health
# {"status":"UP"}

# Prometheus metrics
curl http://localhost:8080/actuator/prometheus
```

---

## Accessing Monitoring

| Service | URL | Credentials |
|---|---|---|
| Grafana | `http://localhost:3000` | admin / admin (set via `.env`) |
| Prometheus | `http://localhost:9090` | — |
| App metrics | `http://localhost:8080/actuator/prometheus` | — |

The pre-loaded dashboard is **Spring Boot 2.1 System Monitor** — it shows JVM memory, CPU, GC activity, HTTP request rates, and HikariCP connection pool metrics.

---

## Stopping

```bash
docker compose down
```

To also remove the database volume (wipes all data):
```bash
docker compose down -v
```
