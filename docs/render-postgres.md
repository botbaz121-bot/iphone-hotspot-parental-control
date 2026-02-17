# Render Postgres (testing)

DB name: hotspot-v1
Region: Oregon (US West)
Plan: Free

## Connection strings

Internal URL (Render private network):
```
postgresql://<user>:<password>@<hostname>/<database>
```

External URL:
```
postgresql://<user>:<password>@<hostname>.oregon-postgres.render.com/<database>
```

PSQL:
```
PGPASSWORD=<password> psql -h <hostname>.oregon-postgres.render.com -U <user> <database>
```
