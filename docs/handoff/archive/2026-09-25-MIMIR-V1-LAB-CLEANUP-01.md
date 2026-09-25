# Handoff archive — MIMIR-V1-LAB-CLEANUP-01

Archived: 2026-09-25
Host: gentoo-Dragon_vm

## Result

The temporary PostgreSQL validation cluster was retired after all required
laboratory evidence, backup/restore validation and canonical bootstrap replay
were completed.

Confirmed before shutdown:

- production schema versions 1..12;
- production schema version 13 absent;
- production mimir_ops role absent;
- temporary PGDATA /var/tmp/mimir-pg13-lab/data;
- temporary port 55432;
- temporary postmaster process matched that PGDATA.

Shutdown:

- pg_ctl stop -m fast;
- socket on 55432 disappeared;
- temporary postmaster exited;
- listener on 55432 disappeared.

Removal:

- real path confirmed as /var/tmp/mimir-pg13-lab;
- temporary tree removed;
- lab directory absent after removal.

Production after cleanup:

- PostgreSQL remained alive on port 5432;
- schema versions remained 1..12;
- schema version 13 remained absent;
- mimir_ops remained absent.

## Next action

Resolve runtime plugin metadata drift and define plugins.allow explicitly.
