#!/usr/bin/env bash
# Streaming replication demo: primary :5432 -> hot standby :5433 (same host, two clusters)
export PGPASSWORD=${PGPASSWORD:-dbadmin}
PRI="psql -h localhost -p 5432 -U dbadmin -d shopnaija -X -q"
REP="psql -h localhost -p 5433 -U dbadmin -d shopnaija -X -q"
echo "=== 1. Replication topology (run on primary)"
$PRI -c "SELECT client_addr, state, sync_state, sent_lsn, replay_lsn FROM pg_stat_replication;"
echo "=== 2. Role check"
$PRI -Atc "SELECT 'primary in_recovery=' || pg_is_in_recovery()"
$REP -Atc "SELECT 'replica in_recovery=' || pg_is_in_recovery()"

echo; echo "=== 3. Write on primary, read from replica (asynchronous replication)"
$PRI -c "UPDATE shop.product SET price = 99999.00 WHERE product_id = 1;"
$PRI -Atc "SELECT 'primary price  = ' || price FROM shop.product WHERE product_id = 1"
$REP -Atc "SELECT 'replica price  = ' || price FROM shop.product WHERE product_id = 1"

echo; echo "=== 4. Replica is read-only (consistency/safety)"
$REP -c "UPDATE shop.product SET price = 1 WHERE product_id = 1;" 2>&1 | sed 's/^psql:.*ERROR:/ERROR:/'

echo; echo "=== 5. Replication lag under a bulk write (10,000 stock-log rows)"
$PRI -q -c "DELETE FROM shop.stock_log WHERE reason = 'bulk';"   # makes re-runs give the same count
$PRI -c "INSERT INTO shop.stock_log(product_id,change_qty,reason) SELECT 1,1,'bulk' FROM generate_series(1,10000);"
$PRI -Atc "SELECT 'lag bytes (primary view) = ' || pg_wal_lsn_diff(sent_lsn, replay_lsn) FROM pg_stat_replication"
$REP -Atc "SELECT 'replica replay delay    = ' || coalesce(now() - pg_last_xact_replay_timestamp(), interval '0')"
sleep 1
$REP -Atc "SELECT 'bulk rows visible on replica = ' || count(*) FROM shop.stock_log WHERE reason='bulk'"

echo; echo "=== 6. SYNCHRONOUS replication: consistency vs availability (CAP in practice)"
$PRI -c "ALTER SYSTEM SET synchronous_standby_names = '*';" -c "SELECT pg_reload_conf();" >/dev/null
sleep 1
$PRI -Atc "SELECT 'sync_state now = ' || sync_state FROM pg_stat_replication"
start=$(date +%s%N); $PRI -c "UPDATE shop.product SET price = 77777 WHERE product_id = 2;"
echo "commit with standby UP returned in $(( ($(date +%s%N) - start) / 1000000 )) ms"
echo "--- standby goes DOWN; a commit on the primary now has to wait for it"
timeout 30 pg_ctlcluster 16 replica stop -m fast
timeout 30 $PRI -c "UPDATE shop.product SET price = 66666 WHERE product_id = 2;" > /tmp/sync_commit.log 2>&1 &
sleep 3
$PRI -Atc "SELECT 'after 3 s the committing session is still waiting: state=' || state || ', wait_event=' || wait_event FROM pg_stat_activity WHERE wait_event = 'SyncRep'"
echo "-> writes are UNAVAILABLE while the only synchronous standby is down (CAP: consistency chosen over availability)"
$PRI -Atc "SELECT pg_cancel_backend(pid) FROM pg_stat_activity WHERE wait_event = 'SyncRep'" >/dev/null
wait
sed 's/^psql:[^:]*:[0-9]*: //' /tmp/sync_commit.log
echo "(after the cancel, the row is committed locally but was NOT confirmed by any standby)"
pg_ctlcluster 16 replica start; sleep 3
$PRI -c "ALTER SYSTEM RESET synchronous_standby_names;" -c "SELECT pg_reload_conf();" >/dev/null
sleep 1
$PRI -Atc "SELECT 'back to sync_state = ' || sync_state FROM pg_stat_replication"

echo; echo "=== 7. FAILOVER: primary 'crashes' (fast stop), replica is promoted"
pg_ctlcluster 16 main stop -m immediate
pg_ctlcluster 16 replica promote; sleep 2
$REP -Atc "SELECT 'new primary in_recovery=' || pg_is_in_recovery()"
$REP -c "UPDATE shop.product SET price = 88888.00 WHERE product_id = 1;" && echo "write accepted on promoted node"
$REP -Atc "SELECT 'service continues, price = ' || price FROM shop.product WHERE product_id = 1"
echo "(restart the old primary and rebuild it as a replica with pg_basebackup/pg_rewind before re-use)"
