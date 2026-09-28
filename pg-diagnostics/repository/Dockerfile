FROM timescale/timescaledb:2.17.2-pg16

# pg_profile — чистое SQL/plpgsql-расширение: достаточно положить файлы в extension dir
ARG PG_PROFILE_VERSION=4.16
ARG PG_PROFILE_SHA256=7c415215681521a2fdbdbe4621add054f9f3f1ce4bd22e7aa7ef7a838de2385f
ADD https://github.com/zubkov-andrei/pg_profile/releases/download/${PG_PROFILE_VERSION}/pg_profile--${PG_PROFILE_VERSION}.tar.gz /tmp/pg_profile.tar.gz
RUN echo "${PG_PROFILE_SHA256}  /tmp/pg_profile.tar.gz" | sha256sum -c - \
 && tar xzf /tmp/pg_profile.tar.gz -C "$(pg_config --sharedir)/extension" \
 && rm /tmp/pg_profile.tar.gz

COPY init/ /docker-entrypoint-initdb.d/
