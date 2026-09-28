#!/bin/sh
# Срез блокировок — каждые LOCKS_INTERVAL_SEC, снимок pg_profile — каждые SAMPLE_INTERVAL_SEC.
# Ошибка одной итерации логируется и не роняет цикл.
set -u
until pg_isready -q; do sleep 2; done
echo "collector started: locks every ${LOCKS_INTERVAL_SEC}s, samples every ${SAMPLE_INTERVAL_SEC}s"

since_sample=$SAMPLE_INTERVAL_SEC
while true; do
    psql -qAt -c "SELECT collect_lock_waits()" >/dev/null || echo "$(date -Is) lock collect failed"
    if [ "$since_sample" -ge "$SAMPLE_INTERVAL_SEC" ]; then
        psql -qAt -c "SELECT server, result FROM take_sample()" || echo "$(date -Is) take_sample failed"
        since_sample=0
    fi
    sleep "$LOCKS_INTERVAL_SEC"
    since_sample=$((since_sample + LOCKS_INTERVAL_SEC))
done
